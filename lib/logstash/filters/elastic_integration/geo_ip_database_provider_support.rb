module LogStash::Filters::ElasticIntegration::GeoIpDatabaseProviderSupport

  LAZY_INIT_MUTEX = Mutex.new
  private_constant :LAZY_INIT_MUTEX

  def geo_ip_database_provider
    @geo_ip_database_provider || LAZY_INIT_MUTEX.synchronize do
      @geo_ip_database_provider ||= _init_geo_ip_database_provider
    end
  end

  def close
    @geo_ip_database_provider&.release
  ensure
    super
  end

  private

  def _get_geo_ip_database_manager
    require File.join(LogStash::Environment::LOGSTASH_HOME, "x-pack/lib/filters/geoip/database_manager")

    LogStash::Filters::Geoip::DatabaseManager.instance
  rescue LoadError
    require 'pry'
    binding.pry
    fail("The GeoIp database manager is not available")
  end

  def _init_geo_ip_database_provider
    GeoIpDatabaseProvider.new(self, _get_geo_ip_database_manager)
  end

  # Implements the Elasticsearch Ingest GeoIp processor's `GeoIpDatabaseProvider`
  # providing separate-and-unsychronized access to a named ES Ingest `GeoIpDatabase`
  # to separately report the validity of a database by its name and to retrieve
  # a database by name. The API does not provide an atomic way to fetch the database
  # and assert its validity.
  class GeoIpDatabaseProvider
    include org.elasticsearch.ingest.geoip.GeoIpDatabaseProvider

    java_import "java.util.concurrent.ConcurrentHashMap"

    def initialize(plugin, database_manager)
      @databases_by_name = ConcurrentHashMap.new
      @logger = plugin.logger

      @city_proxy = DatabaseSyncProxy.new(plugin, "City", self, database_manager)
      @asn_proxy  = DatabaseSyncProxy.new(plugin, "ASN",  self, database_manager)
    end

    def is_valid(database_name)
      !! get_database(database_name)
    end

    def get_database(database_name)
      @databases_by_name.get(database_name)
    end

    def expire(database_name)
      @logger.debug("Received expiry notification for GeoIp database `#{database_name}`; it will be removed")
      @databases_by_name.delete(database_name)&.release
    end

    def update(database_name, database_path)
      @logger.debug("Received update notification for GeoIp database `#{database_name}`; it will be upda`ted")
      @databases_by_name.put(database_name, load_db(database_path))&.release
    end

    def release
      @city_proxy.unsubscribe
      @asn_proxy.unsubscribe

      @databases_by_name.values.map(&:release)
    end

    private

    def load_db(database_path)
      GeoIpDatabase.new(path: database_path, cache_size: 1000)
    end

    # The Logstash-provided Geoip::DatabaseManager needs an object
    # that "quacks like" our GeoIp filter plugin, and relies
    # several of its internals to signal expiries and updates,
    # and to log messages about the updating process.
    class DatabaseSyncProxy

      def initialize(plugin, type, provider, database_manager)
        @plugin = plugin
        @logger = plugin.logger
        @type = type.dup.freeze
        @name = "GeoIP2-#{type.to_s.capitalize}.mmdb".freeze
        @provider = provider

        @database_manager = database_manager

        current_database_path = database_manager.subscribe_database_path(@type, nil, self)

        @logger.debug("GeoIp Database Sync `#{@name}` subscribed with initial path `#{current_database_path}`")
        update_filter(:update, current_database_path)
      end

      # Logstash core's DatabaseManager reaches into the GeoIP filter's
      # execution context to get its pipeline id for logging informational
      # messages about the result of reload or expiry operations.
      # Quack, quack
      def execution_context
        @plugin.execution_context
      end

      # When receive a notification, propagate it to our provider
      # with information about _which_ database the notification is
      # associated with
      def update_filter(action, *args)
        case action
        when :expire then @provider.expire(@name)
        when :update then @provider.update(@name, *args)
        else
          @logger.warn("GeoIp Database Sync `#{@name}` received unsupported notification `#{action}`, which will be ignored")
        end
      end

      def unsubscribe
        @logger.debug("GeoIp Database Sync `#{@name}` unsubscribed`")
        @database_manager.unsubscribe_database_path(@type, self)
      end
    end
  end

  class GeoIpDatabase
    include org.elasticsearch.ingest.geoip.GeoIpDatabase

    java_import "com.maxmind.geoip2.DatabaseReader"
    java_import "com.maxmind.db.CHMCache"
    java_import "java.io.File"

    def initialize(path: , cache_size: 1000)
      @database_reader = DatabaseReader::Builder.new(File.new(path))
                                        .withCache(CHMCache.new(cache_size))
                                        .build
      @database_type = @database_reader.get_metadata.get_database_type
    end

    def get_database_type
      @database_type
    end

    def get_city(inet_address)
      @database_reader.city(inet_address)
    end

    def get_country(inet_address)
      @database_reader.country(inet_address)
    end

    def get_asn(inet_address)
      @database_reader.asn(inet_address)
    end

    def release
      @database_reader.close
    end
  end
end
