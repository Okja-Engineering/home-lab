# ADR-015: Use vLLM for Local Inference

Status: Accepted
Date: 2026-10-14

## Decision

The local inference experiments of Phase 5 serve models with vLLM. This decides the inference engine only. The GX10's operating system, its drivers, how vLLM is deployed on it, which models it serves, and the terms that apply to each of these are decided at Phase 5, after they have been checked.

## Context

The owner has one ASUS GX10. It joins after the workers, the platform services and GitOps, and the AI work on it is learning and testing, initially ([Architecture Vision](../04-architecture-vision.md)).

NVIDIA NIM was considered. NVIDIA describes the API of its NIM containers for large language models as "backed by vLLM" ([NIM API reference](https://docs.nvidia.com/nim/large-language-models/latest/reference/api-reference.html)). The owner chose to learn the engine itself rather than a package built around it.

## Options Considered

- NVIDIA NIM: NVIDIA's packaging of an inference engine (vLLM, SGLang or TensorRT-LLM, depending on the image) with its model profiles ([NIM model profiles](https://docs.nvidia.com/nim/large-language-models/latest/deployment/model-profiles-and-selection.html))
- vLLM (chosen)
- Ollama, or another open-source runtime

## Impact

Phase 5 plans around vLLM, and NIM is not part of the plan. Other runtimes may be tried as comparisons; none is planned.

## Not Doing Yet

The GX10's deployment path, drivers, vLLM version, models and their terms stay open until Phase 5, and so does the use of a second unit ([open decisions](README.md#open-decisions)).

## Review Notes

Revisit this decision at Phase 5 if the vLLM versions available then do not run on the GX10's GPU, or if the owner wants to compare runtimes.
