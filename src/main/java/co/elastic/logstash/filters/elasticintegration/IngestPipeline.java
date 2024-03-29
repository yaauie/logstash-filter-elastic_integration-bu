/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V.
 * under one or more contributor license agreements. Licensed under the
 * Elastic License 2.0; you may not use this file except in compliance
 * with the Elastic License 2.0.
 */
package co.elastic.logstash.filters.elasticintegration;

import org.elasticsearch.ingest.IngestDocument;
import org.elasticsearch.ingest.Pipeline;
import org.elasticsearch.ingest.PipelineConfiguration;

import java.util.Objects;
import java.util.function.BiConsumer;

/**
 * An {@link IngestPipeline} is a Logstash-internal wrapper for an Elasticsearch Ingest {@link Pipeline}.
 */
public class IngestPipeline {
    private final PipelineConfiguration pipelineConfiguration;
    private final Pipeline innerPipeline;

    /**
     * @see IngestPipelineFactory#create(PipelineConfiguration)
     *
     * @param pipelineConfiguration the source ingest pipeline configuration
     * @param innerPipeline an instantiated ingest pipeline
     */
    IngestPipeline(final PipelineConfiguration pipelineConfiguration,
                   final Pipeline innerPipeline) {
        this.pipelineConfiguration = pipelineConfiguration;
        this.innerPipeline = innerPipeline;
    }

    public String getId() {
        return innerPipeline.getId();
    }

    /**
     * This method "quacks like" its counterpart in {@link Pipeline#execute(IngestDocument, BiConsumer)}.
     *
     * @param ingestDocument the Elasticsearch {@link IngestDocument} to execute
     * @param handler a {@link BiConsumer} that handles the result XOR an exception
     */
    public void execute(final IngestDocument ingestDocument,
                        final BiConsumer<IngestDocument, Exception> handler) {
        // IngestDocument#executePipeline includes cyclic reference handling
        ingestDocument.executePipeline(this.innerPipeline, handler);
    }

    @Override
    public boolean equals(final Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        IngestPipeline that = (IngestPipeline) o;
        return pipelineConfiguration.equals(that.pipelineConfiguration);
    }

    @Override
    public int hashCode() {
        return Objects.hash(pipelineConfiguration);
    }

    @Override
    public String toString() {
        return "IngestPipeline{" +
                "id=" + getId() +
                "pipelineConfiguration=" + pipelineConfiguration +
                '}';
    }
}
