using Test
using Logging
using Revise
using Plasm
using LinearAlgebraicRepresentation
using lario3d
# Logging.configure(level==Logging.Debug)


# include("../src/lario3d.jl")
# include("../src/block.jl")


@testset "Map inner face ID to outer ID" begin
    data_size = [2,3,4]
    # block_size = [2,2,2]

#     fid = 15
#     face_cart, axis = lario3d.grid_face_id_to_cartesian(data_size, fid)
#     @test face_cart .= [2, 1, 3]
#     @test axis = 1

#     fid = 37
#     @test face_cart .= [1, 1, 2]
#     @test axis = 2
#     fid = 40
#     @test face_cart .= [1, 1, 4]
#     @test axis = 2
#     fid = 60
#     @test face_cart .= [2, 2, 4]
#     @test axis = 2
#     fid = 85
#     @test face_cart .= [1, 3, 5]
#     @test axis = 3
    fid = 83
    face_cart, axis = lario3d.grid_face_id_to_cartesian(data_size, fid)
    println(face_cart, " ", axis)

#     @test collect(faces) == [1, 13, 22]
    # [1, 13, 2, 14, 3, 15, 5, 17, 6, 18, 7, 19, 37, 45, 38, 46, 39, 47, 69, 72, 74, 77]
end