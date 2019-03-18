#=
block:
- Julia version:
- Author: miros
- Date: 2019-01-16
=#

include("print_function.jl")

"""
seg3d
"""
function number_of_blocks_per_axis(seg3d_size, block_size)
    # print("ahoj")
    blocks_number = Array{Int}(undef, nfields(seg3d_size))
    for k in 1:nfields(seg3d_size)
        # print(k)
        delenec = seg3d_size[k]
        delitel = block_size[k]
        number_for_this_axis = cld(delenec, delitel)
        # print(" ", delenec, ", ", delitel, ", ", number_for_this_axis)

        blocks_number[k] = number_for_this_axis
    end
    return prod(blocks_number), blocks_number
end

function get_block(data3d, block_size, margin_size, blocks_number_axis, block_i)
    a = Array{Int}(
        undef,
        blocks_number_axis[1],
        blocks_number_axis[2],
        blocks_number_axis[3]
    )
    print("block_i: ", block_i)
    bsub = CartesianIndices(a)[block_i]
    bsub_arr = [bsub[1], bsub[2], bsub[3]]

    first = (bsub_arr .== [1, 1, 1])
    last = (bsub_arr .== blocks_number_axis)
    print(bsub, blocks_number_axis, " first last ", first, last, "\n")
    if any(first) || any(last)
        print("end of col, row or slice ", bsub, "\n")

        outdata = zeros(
            eltype(data3d),
            block_size[1] + margin_size,
            block_size[2] + margin_size,
            block_size[3] + margin_size
        )
        xst, xsp, yst, ysp, zst, zsp = data_sub_from_block_sub(
            block_size, margin_size, bsub
        )
        print_slice3(xst, xsp, yst, ysp, zst, zsp)
        xst, oxst, xsh = get_start_and_outstart_ind(xst, margin_size)
        yst, oyst, ysh = get_start_and_outstart_ind(yst, margin_size)
        zst, ozst, zsh = get_start_and_outstart_ind(zst, margin_size)
        print("[", xsh, ", ", ysh, ",", zsh, "]")
        szx, szy, szz = size(data3d)
        bszx, bszy, bszz = block_size
        xsp, oxsp = get_end_and_outend_ind(xst, xsp, szx, xsh)
        ysp, oysp = get_end_and_outend_ind(yst, ysp, szy, ysh)
        zsp, ozsp = get_end_and_outend_ind(zst, zsp, szz, zsh)
        print_slice3(xst, xsp, yst, ysp, zst, zsp)
        print_slice3(oxst, oxsp, oyst, oysp, ozst, ozsp)
        outdata[oxst:oxsp, oyst:oysp, ozst:ozsp] = data3d[
            xst:xsp, yst:ysp, zst:zsp
        ]

    else
        xst, xsp, yst, ysp, zst, zsp = data_sub_from_block_sub(
            block_size, margin_size, bsub
        )
        print(xst, ":", xsp, ", ", yst, ":", ysp, ", ", zst, ":", zsp)
        outdata = data3d[xst:xsp, yst:ysp, zst:zsp]
    end
    return outdata
end


function get_start_and_outstart_ind(xst, margin_size)
    if xst < 1
        oxst = 2 - xst
        xst = 1
        xshift = oxst - xst
    else
        oxst = 1
        xshift = 0
        # xst = xst
    end
    return xst, oxst, xshift
end

function get_end_and_outend_ind(xst, xsp, szx, xsh)
    if szx < xsp
        print("A", xsh)
        oxsp = 1 + szx - xst
        xsp = szx
    else
        print("B", xsh)
        oxsp = 1 + xsp - xst + xsh
        # xsp = xsp
    end
    return xsp, oxsp
end

"""
Get cartesian indices for data from block cartesian indices.
No out of bounds check is performed.
"""
function data_sub_from_block_sub(block_size, margin_size, bsub)
    xst = (block_size[1] * (bsub[1] - 1)) + 1 - margin_size
    xsp = (block_size[1] * (bsub[1] + 0)) + 0 + margin_size
    yst = (block_size[2] * (bsub[2] - 1)) + 1 - margin_size
    ysp = (block_size[2] * (bsub[2] + 0)) + 0 + margin_size
    zst = (block_size[3] * (bsub[3] - 1)) + 1 - margin_size
    zsp = (block_size[3] * (bsub[3] + 0)) + 0 + margin_size
    return xst, xsp, yst, ysp, zst, zsp
end


"""
Get face IDs based on position of cube in grid. Faces IDs along each axis
are returned.

f1, f2, f3 = get_face_ids_from_cube_in_grid([1,2,3], 1, false)
"""
function get_face_ids_from_cube_in_grid(grid_size, cube_carthesian_position, trailing_face::Bool)
    if trailing_face
        trf = 1
    else
        trf = 0
    end
    sz1,sz2,sz3 = grid_size
    i, j, k = cube_carthesian_position
    f10 = (sz2 * sz3) * (i - 1 + trf)  + (j - 1) * sz3 + k
    nax1 = (1 + sz1) * sz2 * sz3
    @debug ("number of 1st axis faces: ", nax1, ", ")
    f20 = nax1 +
        (sz2 + 1) * sz3 * (i - 1)  + (j - 1 + trf) * sz3 + k

    nax2 = sz1 * (1 + sz2) * sz3
    @debug ("2st axis faces: ", nax2, ", ")
    nax3_layer = (sz3 + 1) * sz2 * (i - 1)
    nax3_row = (j - 1) * (sz3 + 1)
    @debug ("3st axis faces in one layer and in one row: ",
        nax3_layer, " ", nax3_row,  "\n")
    f30 = nax1 +  nax2 +
        nax3_layer + nax3_row  + k + trf

    return f10, f20, f30

end







function cartesian_withloops(x,y)
    leny=length(y)
    lenx=length(x)
    m=leny*lenx
    OUT = zeros(eltype(x), m,2)
    c=1
    for i = 1:lenx
        for j = 1:leny
            OUT[c,1] = x[i]
            OUT[c,2] = y[j]
            c+=1
        end
    end
    return OUT
end

function cube_in_block_surface(block_size, cube_start, cube_stop)
    dimension= length(block_size)
    dim = 1
    inner_block_size = cube_stop - cube_start + ones(size(cube_stop))
    number_of_facelets_per_dim = zeros(Int, dimension)
    for i=1:dimension
        print("inner_block_size ", inner_block_size, "\n")
        ones_size = copy(inner_block_size)
        facelet_size_on_this_dim = [ones_size[j] for j=1:length(ones_size) if j != i]
        print("facelet_size", facelet_size_on_this_dim, "\n")
        number_of_facelets_per_dim[i] = prod(facelet_size_on_this_dim)

#         copy
    end
    print("number_of_facelets_per_dim ", number_of_facelets_per_dim, "\n")
    total_number_of_facelets = sum(number_of_facelets_per_dim) * 2

    # output array
    facelet_inds = Array{Int64}(undef, total_number_of_facelets)

#     Array
#     array = Array{Int64}(undef, 5)
    ranges = [collect(cube_start[i]:cube_stop[i]) for i=1:dimension]
    print("ranges ", ranges, "\n")
#     ranges = Array{Any}(undef, dimension)
    cart_index = zeros(Int64, dimension)
    linear_facelet_index = 1
    for i=1:dimension
        rest_dims = [j for j=1:dimension if j != i]
        print("rest dims ", rest_dims, "\n")
        r1 = collect(cube_start[rest_dims[1]]:cube_stop[rest_dims[1]])
        r2 = collect(cube_start[rest_dims[2]]:cube_stop[rest_dims[2]])
        print("r1 ", r1, ",", typeof(r1),"\n")
        print("r2 ", r2, ",", typeof(r2),"\n")
        cartrange_i_dim = cartesian_withloops( r1, r2, )
        println("cartrange_i_dim ", cartrange_i_dim)
        for k=1:size(cartrange_i_dim)[1]
            cart_index_rest = cartrange_i_dim[k, :]
            cart_index[i] = cube_start[i]
            for j=1:(dimension - 1)
                cart_index[rest_dims[j]] = cart_index_rest[j]
            end
            facelet_inds[linear_facelet_index] = get_face_ids_from_cube_in_grid(
                block_size, cart_index, false)[i]
            linear_facelet_index += 1
            cart_index[i] = cube_stop[i]
            facelet_inds[linear_facelet_index] = get_face_ids_from_cube_in_grid(
                block_size, cart_index, true)[i]
            println("facelet_index: ", linear_facelet_index, " cart_index ", cart_index, " index rest ", cart_index_rest)
            linear_facelet_index += 1

        end


#         ranges[i] = collect(cube_start[i]:cube_stop[i])
#         ranges[i] = collect(cube_start[rest_dims[i]]:cube_stop[rest_dims[i]])
#         print("inner_block_size ", inner_block_size, "\n")
#         ones_size = copy(inner_block_size)
#         facelet_size_on_this_dim = [ones_size[j] for j=1:length(ones_size) if j != i]
#         print("facelet_size", facelet_size_on_this_dim, "\n")
#         number_of_facelets_per_dim[i] = prod(facelet_size_on_this_dim)

#         copy
    end
    return facelet_inds
end
#     rest_dims = [2, 3]
#     # shape of flat area (with dimension D-1). One dimension is 1 the other are
#     # the same
#     ones_size = copy(block_size)
#     ones_size[dim] = 1
#     # ones_size = ones(Int64, dimension)
#     # ones_size[dim] = block_size[dim]
#     ones(typeof(cube_start), ones_size...)
#     # cat(dim, )
#     # cartesian_withloops(collect(cubes_start[1]), collect(cube_stop[2]))
#     # for
#     return 1
# end
#
# function a(i)
#     return 1
# end