
#=
surface_test:
- Julia version: 1.1.0
- Author: Jirik
=#
using Distributed
if nprocs() == 1
    addprocs(3)
end
# using Revise
using Test
using Logging
using SparseArrays
using Io3d
# ENV["JULIA_DEBUG"] = "surface_extraction_parallel"
# ENV["JULIA_DEBUG"] = "all"
# using ViewerGL
# using Plasm
# @everywhere using LarSurf
using LarSurf
# @everywhere using Distributed
# global_logger(SimpleLogger(stdout, Logging.Debug))
# # set logger on all workers
# for wid in workers()
#     @spawnat wid global_logger(SimpleLogger(stdout, Logging.Debug))
# end
@testset "Init and deinit" begin
    block_size = [2, 2, 2]
    pth = Io3d.datasets_join_path("medical/orig/sample_data/nrn4.pklz")
    @info "File path " pth
    data = LarSurf.Experiments.report_init_row(@__FILE__)
    V1, FVtri = LarSurf.Experiments.experiment_make_surf_extraction_and_smoothing(
    pth;
    data=data
    )
    assert length(V1) > 1
    assert size(V1, 1) == 3
    assert size(FVtri, 2) == 3
    assert size(FVtri, 1) == size(V1,2)

end
