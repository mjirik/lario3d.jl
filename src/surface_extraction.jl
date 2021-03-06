#=
surface_extraction:
- Julia version: 1.1.0
- Author: Jirik
- Date: 2019-03-19
=#

using SparseArrays
using Distributed
_b3_size = nothing
# ch = nothing
# using LarSurf

function set_block_size(block_size)
    global _b3_size
    _b3_size = size_as_array(block_size)
end

# function set_channel(channel)
#     if channel == nothing
#         ch = RemoteChannel(()->Channel{Int}(32));
#     else
#         ch = channel
#     end
# @everywhere begin
    const chnnel_big_fids = Channel{Int}(32);

    """
    Calculate multiplication linearized volume cells with boundary matrix and
    filter it for number 1.
    """
    function grid_get_surf_Fvec_larmodel(segmentation::AbstractArray)
        segClin = grid_to_linear(segmentation, 0)

        block_size = size_as_array(size(segmentation))

        b3, larmodel = get_boundary3(block_size)
        Flin = segClin' * b3
        # Matrix(Flin)
        sparse_filter!(Flin, 1, 1, 0)
        dropzeros!(Flin)
        return Flin, larmodel
    end

    function grid_get_surf_Fvec_larmodel_old(segmentation::AbstractArray)
        segClin = grid_to_linear(segmentation, 0)

        block_size = size_as_array(size(segmentation))

        b3, larmodel = get_boundary3(block_size)
        V, topology = larmodel
        (VV, EV, FV, CV) = topology
        # println("segmentation: ", size(segmentation))
        # println("segClin: ", size(segClin), " ", typeof(segClin))
        # println("b3: ", size(b3), " ", typeof(b3))
        # println("==========")
        Flin = segClin' * b3
        # Matrix(Flin)
        sparse_filter_old!(Flin, 1, 1, 0)
        dropzeros!(Flin)
        return Flin, larmodel
    end

    """
    Construct B matrix and make multiplication with boundary3.
    B matrix composed from faces per block. The size of block is constant.
    """
    function grid_get_surface_Bchar_loc_fixed_block_size(segmentation::AbstractArray, block_size::AbstractArray{Int,1})
        data_size = size_as_array(size(segmentation))
        margin_size = 0
        block_number, blocks_number_axis = number_of_blocks_per_axis(
            data_size, block_size)

        tmp_img_size = blocks_number_axis::AbstractArray{Int, 1} .* block_size::Array{Int,1}
        # numF = grid_number_of_faces(block_size)
        numC = prod(block_size)
        # println("numC = $numC, block_number = $block_number")
        Slin = spzeros(Int8, numC, block_number)
        offsets = Array{Array,1}(undef, block_number)

        # block_size = size_as_array(size(segmentation))
        # oneS=1
        fixed_block_size=true
        for block_i=1:block_number
            block1, offset1, block_size1 = get_block(block_i,
                segmentation, block_size, margin_size, blocks_number_axis,
                fixed_block_size
            )
            oneS =  grid_to_linear(block1, 0)
            # println("Slin[$block_i, :] = ", oneS)
            # display(block1)
            Slin[:, block_i] = oneS[:, 1]
            offsets[block_i] = offset1
        end
        b3, larmodel = get_boundary3(block_size)
        # ------
        Bchar = Slin' * b3
        # Bchar is similar to Flin
        # ------
        sparse_filter!(Bchar, 1, 1, 0)
        dropzeros!(Bchar)
        return Bchar, offsets, blocks_number_axis, larmodel
        # return Slin, oneS, b3
    end

    """
    Construct B matrix and make multiplication with boundary3.
    B matrix composed from faces per block. The size of block is constant.
    """
    function grid_get_surface_Bchar_loc_fixed_block_size_parallel(segmentation::AbstractArray, block_size::AbstractArray{Int,1})
        # TODO parallelization
        data_size = size_as_array(size(segmentation))
        margin_size = 0
        block_number, blocks_number_axis = number_of_blocks_per_axis(
            data_size, block_size)

        tmp_img_size = blocks_number_axis::AbstractArray{Int, 1} .* block_size::Array{Int,1}
        # numF = grid_number_of_faces(block_size)
        numC = prod(block_size)
        # println("numC = $numC, block_number = $block_number")
        Slin = spzeros(Int8, numC, block_number)
        offsets = Array{Array,1}(undef, block_number)

        # block_size = size_as_array(size(segmentation))
        # oneS=1
        fixed_block_size=true
        @sync @distributed for block_i=1:block_number
            block1, offset1, block_size1 = get_block(block_i,
                segmentation, block_size, margin_size, blocks_number_axis,
                fixed_block_size
            )
            oneS =  grid_to_linear(block1, 0)
            # println("Slin[$block_i, :] = ", oneS)
            # display(block1)
            Slin[:, block_i] = oneS[:, 1]
            offsets[block_i] = offset1
        end
        b3, larmodel = get_boundary3(block_size)
        # ------
        Bchar = Slin' * b3
        # Bchar is similar to Flin
        # ------
        sparse_filter!(Bchar, 1, 1, 0)
        dropzeros!(Bchar)
        return Bchar, offsets, blocks_number_axis, larmodel
        # return Slin, oneS, b3
    end

    function __make_return(V, filteredFV, Flin, larmodel, return_all)
        if return_all
            return (V, [filteredFV]), Flin, larmodel
        else
            return (V, [filteredFV])
        end
    end

    """
    return
    surfaceLARmodel, Flin, fullLARmodel
    """
    function get_surface_grid(segmentation::AbstractArray; return_all::Bool=false)
        Flin, larmodel = grid_get_surf_Fvec_larmodel(segmentation)

        V = larmodel[1]
        FV = larmodel[2][3]
        inds1, inds2, vals = findnz(Flin)

        filteredFV = [FV[inds2[i]] for i=1:length(inds2)]

        # filteredFV = [FV[i] for i=1:length(Flin) if (Flin[i] == 1)]
        return __make_return(V, filteredFV, Flin, larmodel, return_all)
        # if return_all
        #     return (V, [filteredFV]), Flin, larmodel
        # else
        #     return (V, [filteredFV])
        # end
    end



    function get_surface_grid_old(segmentation::AbstractArray; return_all::Bool=false)
        Flin, larmodel = grid_get_surf_Fvec_larmodel_old(segmentation)
        V, topology = larmodel
        (VV, EV, FV, CV) = topology

        filteredFV = [FV[i] for i=1:length(Flin) if (Flin[i] == 1)]
        return __make_return(V, filteredFV, Flin, larmodel, return_all)
        # if return_all
        #     return (V, [filteredFV]), Flin, larmodel
        # else
        #     return (V, [filteredFV])
        # end
    end

    """
    Based on input segmentation and block size calculate filtered FV and full sparse FV.
    In sparse FV is number 1 where is the surface. There is also number 2 where is
    the edge between blocks.
    """
    function __grid_get_surface_Fchar_per_block(segmentation::AbstractArray, block_size::Array{Int,1})
        data_size = size_as_array(size(segmentation))
        numF = grid_number_of_faces(data_size)
        # print("size vs length vs grid_number_of_faces: ", szF, " ", lenF, " ", numF)
        # print("size vs length vs grid_number_of_faces: ", typeof(szF), " ", typeof(lenF), " ", typeof(numF))

        # block_size = [2, 3, 4]
        margin_size = 0
        block_number, blocks_number_axis = number_of_blocks_per_axis(
            data_size, block_size)

        bigFchar = spzeros(Int8, numF)
        # println("bigFchar ", size(bigFchar))
        Flin = Nothing
        # println("block number ", block_number, " block size: ", block_size, "margin size: ", margin_size,
        #     " block number axis: ", blocks_number_axis)
        for block_i=1:block_number
            block_seg, offset1, block_size1 = get_block(
                block_i,
                segmentation, block_size, margin_size, blocks_number_axis, false
            )

            # filteredFVi, Flin, (V, model) = get_surface_grid(segmentation1; return_all=true)
            # (VV, EV, FV, CV) = model
            # println("=== segmentation")
            # display(block_seg)
            Flin, larmodel = grid_get_surf_Fvec_larmodel(block_seg)

        # face from small to big
            i, j, v = findnz(Flin)
            # println("=== findnz 2")
            # display(Flin)
            # println("Flin i j v, ", length(i)," ", length(v), " bigFchar ", nnz(bigFchar))
            for fid in j
                big_fid, voxel_cart = sub_grid_face_id_to_orig_grid_face_id(data_size, block_size1, offset1, fid)
                # if it is 0 set it one
                # if it is 1 there are two faces (prev and current) so remove
                # if bigFchar[big_fid] == 0
                bigFchar[big_fid] = (bigFchar[big_fid] + 1) % 2
                # bigFchar[big_fid] += 1
                # print(".")
            end
        end
        dropzeros!(bigFchar)
        return bigFchar
    end


    """
        block_params = (block_i, segmentation, block_size, margin_size,
            blocks_number_axis, fixed_block_size)

        __grid_get_surface_get_Fids_used_in_block(block_i, block_getter...)
    """
    function __grid_get_surface_get_Fids_used_in_block(
        block_i, segmentation, block_size, margin_size, blocks_number_axis, fixed_block_size
        )
        # = block_params

        segmentation_block, offset1, block_size1 = get_block(block_i,
            segmentation, block_size, margin_size, blocks_number_axis, fixed_block_size
        )
        if fixed_block_size
            block_size1 = block_size
        end
        data_size = size_as_array(size(segmentation))
        Flin, larmodel = grid_get_surf_Fvec_larmodel(segmentation_block)

    # face from small to big
        i, j, v = findnz(Flin)
        return [
            sub_grid_face_id_to_orig_grid_face_id(data_size, block_size1, offset1, fid)[1]
            for fid in j
        ]
    end

    """
    Put Fids used in block into channel
        block_params = (block_i, segmentation, block_size, margin_size,
            blocks_number_axis, fixed_block_size)

        __grid_get_surface_get_Fids_used_in_block(block_i, block_getter...)
    """
    function __grid_get_surface_channel_Fids_used_in_block(
        channel,
        block_i, segmentation, block_size, margin_size, blocks_number_axis, fixed_block_size
        )
        # = block_params

        segmentation_block, offset1, block_size1 = get_block(block_i,
            segmentation, block_size, margin_size, blocks_number_axis, fixed_block_size
        )
        if fixed_block_size
            block_size1 = block_size
        end
        data_size = size_as_array(size(segmentation))
        Flin, larmodel = grid_get_surf_Fvec_larmodel(segmentation_block)

    # face from small to big
        i, j, v = findnz(Flin)
        for fid in j
            print("_")
            put!(channel,
                sub_grid_face_id_to_orig_grid_face_id(data_size, block_size1, offset1, fid)[1]
            )
        end
        put!(channel, -1)

    end
    function __fcn_doing_nothing(block)
        @info "info doing nothing"
        return block + 1
    end
    function __fcn_doing_print(block)
        println(block)
        return block
    end

    """
    Based on input segmentation and block size calculate filtered FV and full sparse FV.
    In sparse FV is number 1 where is the surface. There is also number 2 where is
    the edge between blocks.
    """
    function __grid_get_surface_Fchar_per_block_parallel_pmap(segmentation::AbstractArray, block_size::Array{Int,1}; fixed_block_size=false)
        data_size = size_as_array(size(segmentation))
        numF = grid_number_of_faces(data_size)

        block_number, bgetter = block_getter(segmentation, block_size; fixed_block_size=fixed_block_size)
        # data3d, block_size, u, blocks_per_axis, fixed_block_s = bgetter
        # block_number, blocks_number_axis = number_of_blocks_per_axis(
        #     data_size, block_size)

        # @everywhere function get_Fids(block_i)
        #     return __grid_get_surface_get_Fids_used_in_block(block_i, bgetter...)
        # end

        # get_Fids(block_i) = __grid_get_surface_get_Fids_used_in_block(block_i, bgetter...)
        # get_Fids = function(block_i)
        # end
        # variable1 = 2
        get_Fids = function(block_i)
            # __fcn_doing_print(bgetter)
             # return __grid_get_surface_get_Fids_used_in_block(block_i, data3d, block_size, u, blocks_per_axis, fixed_block_s)
             return __grid_get_surface_get_Fids_used_in_block(block_i, bgetter...)
            # return variable1 * __fcn_doing_nothing(block_i)

        end


        bigFchar = spzeros(Int8, numF)
        # println("bigFchar ", size(bigFchar))
        # Flin = Nothing

        faces_per_blocks = pmap(get_Fids, 1:block_number)
        for  block_i=1:block_number
            for big_fid in faces_per_blocks[block_i]

                bigFchar[big_fid] = (bigFchar[big_fid] + 1) % 2
            end
        end
        dropzeros!(bigFchar)
        return bigFchar
    end


    function __temp(ch, block_i, bgetter...)
        # This __grid_get ... function is invisible for other workers
        return __grid_get_surface_channel_Fids_used_in_block(ch, block_i, bgetter...)
    end


    """
    Based on input segmentation and block size calculate filtered FV and full sparse FV.
    In sparse FV is number 1 where is the surface. There is also number 2 where is
    the edge between blocks.
    """
    function __grid_get_surface_Fchar_per_block_parallel_channel(
        segmentation::AbstractArray, block_size::Array{Int,1},
        channel::RemoteChannel
        ;
        fixed_block_size=false
        )
        # println("begin get surface")
        data_size = size_as_array(size(segmentation))
        numF = grid_number_of_faces(data_size)

        block_number, bgetter = block_getter(segmentation, block_size; fixed_block_size=fixed_block_size)
        # c = Channel{Int64}(32)

        # @everywhere put_Fids(block_i) = __grid_get_surface_channel_Fids_used_in_block(ch, block_i, bgetter...)

        bigFchar = spzeros(Int8, numF)
        # println("bigFchar ", size(bigFchar))
        # put!(channel, 1)
        # put!(channel, 3)
        # put!(channel, -2)
        # put!(channel, 2)
        # println("put in channedl")
        Flin = Nothing
        # println("before distributed")
        @distributed for block_i=1:block_number
            # print(".")
            put!(channel, -3)
            __fcn_doing_print(block_i)
            # __grid_get_surface_channel_Fids_used_in_block(ch, block_i, bgetter...)
            # __temp(ch, block_i, bgetter...)
            # print(",")
            # put_Fids(block_i)
        end

        # println("after distributed")
        n = 0
        # println("parallel processing, expected n = $block_number")
        # while n < block_number
        while n < 3
            big_fid = take!(channel)
            # print("$big_fid,")
            if big_fid < 0
                n += 1
            else
                bigFchar[big_fid] = (bigFchar[big_fid] + 1) % 2
            end
        end
        dropzeros!(bigFchar)
        return bigFchar
    end
    """
    Compatibility with interface of all other get_Fchar functions
    """
    function __grid_get_surface_Fchar_per_block_parallel_channel(
        segmentation::AbstractArray, block_size::Array{Int,1}
        ;
        channel::RemoteChannel=nothing,
        fixed_block_size=false
        )
        if channel == nothing
            channel = RemoteChannel(()->Channel{Int}(32));
        end
        return __grid_get_surface_Fchar_per_block_parallel_channel(
            segmentation::AbstractArray, block_size::Array{Int,1},
            channel::RemoteChannel
            ;
            fixed_block_size=false
        )
    end

    """
    Based on input segmentation and block size calculate filtered FV and full sparse FV.
    In sparse FV is number 1 where is the surface. There is also number 2 where is
    the edge between blocks.
    """
    __grid_get_surface_Fchar_per_block_parallel = __grid_get_surface_Fchar_per_block_parallel_pmap

    function __grid_get_surface_Fchar_per_block_old_implementation(segmentation::AbstractArray, block_size::Array{Int,1})
        data_size = size_as_array(size(segmentation))
        numF = grid_number_of_faces(data_size)
        # print("size vs length vs grid_number_of_faces: ", szF, " ", lenF, " ", numF)
        # print("size vs length vs grid_number_of_faces: ", typeof(szF), " ", typeof(lenF), " ", typeof(numF))

        # block_size = [2, 3, 4]
        margin_size = 0
        block_number, blocks_number_axis = number_of_blocks_per_axis(
            data_size, block_size)

        # bigFchar = spzeros(Int8, lenF)
        bigFchar = spzeros(Int8, numF)
        Flin = Nothing
        @debug "block number ", block_number, " block size: ", block_size, "margin size: ", margin_size,
            " block number axis: ", blocks_number_axis
        for block_i=1:block_number
            block1, offset1, block_size1 = get_block(block_i,
                segmentation, block_size, margin_size, blocks_number_axis
            )
            segmentation1 = block1

            filteredFVi, Flin, (V, model) = get_surface_grid_old(segmentation1; return_all=true)
            (VV, EV, FV, CV) = model

        # face from small to big

            for fid=1:length(Flin)
                if (Flin[fid] == 1)

                    big_fid, voxel_cart = sub_grid_face_id_to_orig_grid_face_id(data_size, block_size1, offset1, fid)
                    bigFchar[big_fid] += 1

                end
            end
        end
        return bigFchar
    end


    """
    Calculate Flin using multiplication b3 * S.
    Output is Flin and new size of image data. It is bigger than the original one
    because of limitation of fixed block size.
    """
    function __grid_get_surface_Fchar_per_fixed_block_size(segmentation::AbstractArray, block_size::AbstractArray{Int,1})
        # B is F per bricks
        B, offsets, blocks_number_axis, larmodel1 = grid_get_surface_Bchar_loc_fixed_block_size(segmentation, block_size)
        data_size = size_as_array(size(segmentation))


        tmp_data_size = block_size .* blocks_number_axis
        numF = grid_number_of_faces(tmp_data_size)
        bigFchar = spzeros(Int8, numF)

        for nzout in zip(findnz(B)...)
            block_id, fid, val = nzout
            offset1 = offsets[block_id]
            big_fid, voxel_cart = sub_grid_face_id_to_orig_grid_face_id(tmp_data_size, block_size, offset1, fid)
            bigFchar[big_fid] = (bigFchar[big_fid] + 1) % 2

        end

        dropzeros!(bigFchar)
        return bigFchar, tmp_data_size
    end
    # =====================

    function get_surface_grid_per_block_general(
        segmentation::AbstractArray, block_size::ArrayOrTuple, face_extraction_fcn, model_extraction_fcn; return_all::Bool=false)
        Fchar = face_extraction_fcn(segmentation, block_size)
        data_size = size_as_array(size(segmentation))
        bigV, FVreduced = model_extraction_fcn(Fchar, data_size)
        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, model)
        else
            return (bigV,[FVreduced])
        end
    end


    get_surface_grid_per_block_full2(segmentation::AbstractArray, block_size::ArrayOrTuple; return_all::Bool=false
        ) = get_surface_grid_per_block_general(
            segmentation, block_size,
            __grid_get_surface_Fchar_per_block,
            grid_Fchar_to_V_FVfulltoreduced,
            )




    function get_surface_grid_per_block_full(segmentation::AbstractArray, block_size::ArrayOrTuple; return_all::Bool=false)
        Fchar = __grid_get_surface_Fchar_per_block(segmentation, block_size)

        data_size = size_as_array(size(segmentation))
        # bigV, (bigVV, bigEV, bigFV, bigCV) = Lar.cuboidGrid(data_size, true)
        # model = (bigVV, bigEV, bigFV, bigCV)
        bigV, FVreduced = grid_Fchar_to_V_FVfulltoreduced(Fchar, data_size)
        model = [FVreduced]

        # return filtered_bigFV, Fchar, (bigV, model)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, model)
        else
            return (bigV,[FVreduced])
        end
    end


    """
    Construction of FV is reduced. The V
    """
    function get_surface_grid_per_block_Vreduced_FVreduced(segmentation::AbstractArray, block_size::ArrayOrTupleOrNothing=nothing; return_all::Bool=false)
        block_size = get_global_block_size_if_necessary(block_size)
        Fchar = __grid_get_surface_Fchar_per_block(segmentation, block_size)
        # println("Fchar ", size(Fchar))

        data_size = size_as_array(size(segmentation))
        # bigV, (bigVV, bigEV, bigFV, bigCV) = Lar.cuboidGrid(data_size, true)
        # model = (bigVV, bigEV, bigFV, bigCV)
        bigV, FVreduced = grid_Fchar_to_Vreduced_FVreduced(Fchar, data_size)

        # return filtered_bigFV, Fchar, (bigV, model)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, [FVreduced])
        else
            return (bigV,[FVreduced])
        end
    end

    """
    Construction of FV is reduced. The V
    """
    function get_surface_grid_per_block_Vreduced_FVreduced_parallel(segmentation::AbstractArray, block_size::ArrayOrTupleOrNothing=nothing; return_all::Bool=false)
        block_size = get_global_block_size_if_necessary(block_size)
        Fchar = __grid_get_surface_Fchar_per_block_parallel_pmap(segmentation, block_size)
        # println("Fchar ", size(Fchar))

        data_size = size_as_array(size(segmentation))
        # bigV, (bigVV, bigEV, bigFV, bigCV) = Lar.cuboidGrid(data_size, true)
        # model = (bigVV, bigEV, bigFV, bigCV)
        bigV, FVreduced = grid_Fchar_to_Vreduced_FVreduced(Fchar, data_size)

        # return filtered_bigFV, Fchar, (bigV, model)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, [FVreduced])
        else
            return (bigV,[FVreduced])
        end
    end
    """
    Construction of FV is reduced. The V
    """
    function get_surface_grid_per_block_Vreduced_FVreduced_fixed_block_size(segmentation::AbstractArray, block_size::ArrayOrTupleOrNothing=nothinge; return_all::Bool=false)
        block_size = get_global_block_size_if_necessary(block_size)
        # grid_get_surface_Bchar_loc_fixed_block_size
        Fchar, new_data_size = __grid_get_surface_Fchar_per_fixed_block_size(segmentation, block_size)
        bigV, FVreduced = grid_Fchar_to_Vreduced_FVreduced(Fchar, new_data_size)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, [FVreduced])
        else
            return (bigV,[FVreduced])
        end
    end

    function get_surface_grid_per_block_Vreduced_FVreduced_old(segmentation::AbstractArray, block_size::ArrayOrTupleOrNothing=nothing; return_all::Bool=false)
        block_size = get_global_block_size_if_necessary(block_size)
        Fchar = __grid_get_surface_Fchar_per_block_old_implementation(segmentation, block_size)

        data_size = size_as_array(size(segmentation))
        # bigV, (bigVV, bigEV, bigFV, bigCV) = Lar.cuboidGrid(data_size, true)
        # model = (bigVV, bigEV, bigFV, bigCV)
        bigV, FVreduced = grid_Fchar_to_Vreduced_FVreduced_old(Fchar, data_size)

        # return filtered_bigFV, Fchar, (bigV, model)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, [FVreduced])
        else
            return (bigV,[FVreduced])
        end
    end


    function get_surface_grid_per_block_FVreduced(segmentation::AbstractArray, block_size::ArrayOrTupleOrNothing=nothing; return_all::Bool=false)
        block_size = get_global_block_size_if_necessary(block_size)
        Fchar = __grid_get_surface_Fchar_per_block(segmentation, block_size)

        data_size = size_as_array(size(segmentation))
        bigV, FVreduced = grid_Fchar_to_V_FVreduced(Fchar, data_size)

        # return filtered_bigFV, Fchar, (bigV, model)

        if return_all
            return (bigV,[FVreduced]), Fchar, (bigV, [FVreduced])
        else
            return (bigV,[FVreduced])
        end
    end

    function get_surface_grid_per_block(segmentation::AbstractArray, block_size::ArrayOrTuple; return_all::Bool=false)
        return get_surface_grid_per_block_Vreduced_FVreduced(segmentation, block_size; return_all=return_all)
    end

# end
