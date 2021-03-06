# # using Revise
using Test
using Logging
using LarSurf
using SparseArrays
# using Pio3d
# using BenchmarkTools

interactive = false
if interactive
    using Plasm
end
# using LinearAlgebraicRepresentation
# Lar = LinearAlgebraicRepresentation
# Logging.configure(level==Logging.Debug)


# include("../src/LarSurf.jl")
# include("../src/block.jl")

@testset "test smoothing" begin
    # xystep = 1
    # zstep = 1
    # threshold = 4000;
    # pth = Pio3d.datasets_join_path("medical/orig/sample-data/nrn4.pklz")
    # datap = Pio3d.read3d(pth)
    # data3d = datap["data3d"]
    # segmentation = data3d .> threshold

    segmentation = LarSurf.generate_minecraft_kidney(30)

    block_size = [5,5,5]
    basicmodel, Flin, larmodel = LarSurf.get_surface_grid_per_block(segmentation, block_size; return_all=true)
    someV, topology = basicmodel
    FV = topology[1]
    bigV = someV
    # @info "smoothing_FV test" bigV FV FV[1]
    # Quads -> smoothing -> triangulation
    Vqs = LarSurf.Smoothing.smoothing_FV(bigV, FV, 0.6)
    @test typeof(Vqs) <: Array

    # Plasm.View((Vqs * 100, [FV]))

    FVtri = LarSurf.triangulate_quads(FV)
    if interactive
        Plasm.View((Vqs * 100, [FVtri]))
    end
    # Smoothi accoarding to trinagle faces
    # Quads -> triangulation -> Smoothing
    Vts = LarSurf.Smoothing.smoothing_FV(bigV, FVtri, 0.6)
    @test typeof(Vts) <: Array
    @test size(Vts,1) == 3

    for i = 1:5
        Vts = LarSurf.Smoothing.smoothing_FV(Vts, FVtri, 0.6)
    end
    if interactive
        Plasm.View((Vqs * 100, [FVtri]))
    end
    # taubin
    Vts = LarSurf.Smoothing.smoothing_FV(bigV, FVtri, 0.6)
    for i = 1:5
        Vts = LarSurf.Smoothing.smoothing_FV(Vts, FVtri, 0.6)
        Vts = LarSurf.Smoothing.smoothing_FV(Vts, FVtri, -0.2)
    end
    if interactive
        Plasm.View((Vqs * 100, [FVtri]))
    end
    @test typeof(Vts) <: Array
    @test size(Vts,1) == 3
end


@testset "test iterative smoothing" begin
    segmentation = LarSurf.generate_minecraft_kidney(30)

    block_size = [5,5,5]
    basicmodel = LarSurf.get_surface_grid_per_block(segmentation, block_size; return_all=false)
    someV, topology = basicmodel
    FV = topology[1]
    bigV = someV
    # @info "smoothing_FV test" bigV FV FV[1]
    # Quads -> smoothing -> triangulation
    Vqs = LarSurf.Smoothing.smoothing_FV(bigV, FV, 0.6, 5)
    @test typeof(Vqs) <: Array
    @test size(Vqs,1) == 3
end
@testset "test iterative smoothing small" begin
    # segmentation = LarSurf.generate_minecraft_kidney(6)
    # segmentation = zeros(np)
    #
    # Vertex IDs first is on level 2 in Z-axis and second is on level 3
    #         6,5   15,1
    #  4         *------*
    #            |      |
    #       11,12|  3,14|     9,10
    #  3         *------*------*
    #            |      |      |
    #        1,16|  13,8|   4,7|
    #  2         *------*------*
    #
    #            2      3      4


    seg = zeros(Int8, 4,4,4)
    seg[2,2,2] = 1
    seg[2,3,2] = 1
    seg[3,2,2] = 1
    segmentation = seg .> 0

    block_size = [2,2,2]
    basicmodel = LarSurf.get_surface_grid_per_block(segmentation, block_size; return_all=false)
    someV, topology = basicmodel
    FV = topology[1]
    bigV = someV
    # @info "smoothing_FV test" bigV FV FV[1]
    # Quads -> smoothing -> triangulation
    testEV = LarSurf.Smoothing.get_EV_quads(FV)
    Vqs = LarSurf.Smoothing.smoothing_FV(bigV, FV, 0.6, 1)
    @test typeof(Vqs) <: Array
    @test size(Vqs,1) == 3
end

@testset "test iterative taubin smoothing" begin
    segmentation = LarSurf.generate_minecraft_kidney(30)

    block_size = [5,5,5]
    basicmodel = LarSurf.get_surface_grid_per_block(segmentation, block_size; return_all=false)
    someV, topology = basicmodel
    FV = topology[1]
    bigV = someV
    # @info "smoothing_FV test" bigV FV FV[1]
    # Quads -> smoothing -> triangulation
    Vqs = LarSurf.Smoothing.smoothing_FV_taubin(bigV, FV, 0.6, -0.4, 5)
    @test typeof(Vqs) <: Array
    @test size(Vqs,1) == 3
end

@testset "test get_EV" begin
    larmodel = LarSurf.Lar.cuboidGrid([1,1,2], true)
    V, topology = larmodel
    VV, EVorig, FV, CV = topology
    deleteat!(FV,10)
    # FVsurf = cat([FV[1:9], FV[11:end]])
    EVset = LarSurf.Smoothing.get_EV_quads(FV)
    EVdouble = LarSurf.Smoothing.get_EV_quads2(FV)
    @test length(EVset[1]) == 2
    @test length(EVdouble[1]) == 2
    # @test EVset::Array{Array,1}

    # Plasm.View((V, [EVset, FV]))
    # Plasm.View((V, [EV, FV]))
end
