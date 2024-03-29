/*
 * Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V.
 * under one or more contributor license agreements. Licensed under the
 * Elastic License 2.0; you may not use this file except in compliance
 * with the Elastic License 2.0.
 */
package co.elastic.logstash.filters.elasticintegration.util;

import java.io.File;
import java.net.URL;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Objects;
import java.util.Optional;

import static co.elastic.logstash.filters.elasticintegration.util.ResourcesUtil.getResourcePath;

public class LocalPipelinesUtil {
    public static Path getPreparedPipelinesResourcePath(final Class<?> resourceProvider, final String packageRelativePath) {
        return getResourcePath(resourceProvider, packageRelativePath)
                .map(ResourcesUtil::ensureContentsReadableNonWritable)
                .orElseThrow(() -> new IllegalArgumentException(String.format("failed to load resource for `%s`", packageRelativePath)));
    }

    public static Optional<Path> getResourcePath(final Class<?> resourceProvider, final String packageRelativePath) {
        return Optional.ofNullable(resourceProvider.getResource(packageRelativePath))
                .map(URL::getPath)
                .map(Paths::get);
    }

    static Path ensureContentsReadableNonWritable(Path path) {
        for (File file : Objects.requireNonNull(path.toFile().listFiles())) {
            ensureSetFileReadable(file, true);
            ensureSetFileWritable(file, false);
        }
        return path;
    }

    public static void ensureSetFileReadable(File file, boolean desiredState) {
        if (desiredState != file.canRead()) {
            if (!file.setReadable(desiredState)) {
                throw new IllegalStateException(String.format("failed to ensure readable=%s for file: %s", desiredState, file));
            }
        }
    }
    public static void ensureSetFileWritable(File file, boolean desiredState) {
        if (desiredState != file.canWrite()) {
            if (!file.setWritable(desiredState)) {
                throw new IllegalStateException(String.format("failed to ensure writable=%s for file: %s", desiredState, file));
            }
        }
    }
}
