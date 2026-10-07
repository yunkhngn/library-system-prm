package com.library.checkin.dto;

import java.util.List;

public record InternalEmbeddingResult(
        List<List<Double>> embeddings,
        int dimension,
        String modelId,
        String modelVersion,
        boolean simulated
) {}
