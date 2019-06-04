
using Test
using Logging
using Revise
using LarSurf
using Plasm
using LinearAlgebraicRepresentation
Lar = LinearAlgebraicRepresentation

fn = "exp_surface_extraction2.csv"

prepare_data = LarSurf.generate_almost_cube
prepare_data = LarSurf.generate_cube

segmentation = prepare_data(10)

fcns = [
    LarSurf.get_surface_grid_per_block_Vreduced_FVreduced_parallel
    LarSurf.get_surface_grid_per_block_Vreduced_FVreduced_fixed_block_size,
    LarSurf.get_surface_grid_per_block_Vreduced_FVreduced_old,
    LarSurf.get_surface_grid_per_block_Vreduced_FVreduced,
    LarSurf.get_surface_grid_per_block_FVreduced,
    LarSurf.get_surface_grid_per_block_full,
    LarSurf.get_surface_grid_old,
    LarSurf.get_surface_grid,
    # LarSurf.get_surface_grid_per_block,
    # LarSurf.get_surface_grid_per_block,
    # LarSurf.get_surface_grid_per_bloc,
]
# set first two are with one parameter
nargs = 2 * ones(Int64, length(fcns))
nargs[1:2] .= 1
# inargs = [segmentation, block_size]
fcns_nargs = collect(zip(fcns, nargs))

# it is list with just fast functions
fcns_fast = fcns_nargs[1:end-3]
fcns_all  = fcns_nargs

# fcns_nargs_local = fcns_nargs[1:end]
# end
# fcns_nargs = [
#     (fcns[i], nargs[])
#     # (fcns[i], inargs[1:nargs[i]])
#     for i=1:length(fcns)
# ]



# Warm up on small data

block_size = [2,2,2]
for (fcni, nargs) in fcns_nargs
    argsi = [segmentation, block_size]
    fcni(argsi[1:nargs]...)
end


function save_data(experiment, timed, segmentation, b3_size, append_dct)
    tm = timed[2]
    al = timed[3]
    println(" time=$tm, alloc=$al")
    dct = Dict()
    dct = LarSurf.timed_to_dict!(dct, timed;experiment=experiment)
    dct = LarSurf.segmentation_description_to_dict!(dct, segmentation)
    dct = LarSurf.size_to_dict!(dct, b3_size, "boundary3_")
    if append_dct != nothing
        merge!(dct, append_dct)
    end
    LarSurf.add_to_csv(dct, fn)
end


"""
fcns_nargs_local
"""
function run_measurement(fcns_nargs_local, segmentation_size_factor, block_size, experiment=nothing; append_dct=nothing)
    if experiment == nothing
        experiment = "time measurement"
    end
    println(experiment)
    segmentation = prepare_data(segmentation_size_factor)
    for (fcni, nargs) in fcns_nargs_local
        argsi = [segmentation, block_size]
        tmd = @timed(fcni(argsi[1:nargs]...))
        if append_dct == nothing
            append_dct = Dict()
        end
        append_dct["fcn"] = String(Symbol(fcni))

        save_data(experiment, tmd, segmentation, block_size, append_dct)
    end
    println("============================")
end

# Warming
run_measurement(fcns_all , 10, [1,1,1] .*  8, "warming")
run_measurement(fcns_fast, 20, [1,1,1] .* 16, "warming"; skip_slow=true)
run_measurement(fcns_fast, 40, [1,1,1] .* 32, "warming"; skip_slow=true)
run_measurement(fcns_fast, 70, [1,1,1] .* 64, "warming"; skip_slow=true)

# Experiments

for i=1:1
    ## Small
    run_measurement(fcns_fast,  40, [1,1,1] .* 16, "small b3")
    run_measurement(fcns_fast,  40, [1,1,1] .* 16, "small b3")
    run_measurement(fcns_fast,  40, [1,1,1] .* 16, "small b3")

    ## Datasize, constant b3

    run_measurement(fcns_fast,  20, [1,1,1] .* 64, "data size")
    run_measurement(fcns_fast,  40, [1,1,1] .* 64, "data size")
    run_measurement(fcns_fast,  80, [1,1,1] .* 64, "data size")
    run_measurement(fcns_fast, 160, [1,1,1] .* 64, "data size")
    run_measurement(fcns_fast, 320, [1,1,1] .* 64, "data size")
    run_measurement(fcns_fast, 512, [1,1,1] .* 64, "data size")

    ## Boundary matrix size

    run_measurement(fcns_fast, 100, [1,1,1] .*  8, "boundary size")
    run_measurement(fcns_fast, 100, [1,1,1] .* 16, "boundary size")
    run_measurement(fcns_fast, 100, [1,1,1] .* 32, "boundary size")
    run_measurement(fcns_fast, 100, [1,1,1] .* 64, "boundary size")
    # run_measurement(fcns_fast,100, [1,1,1] .* 64, "data size"; skip_slow=true)
    run_measurement(fcns_fast, 512, [1,1,1] .*  8, "boundary size big")
    run_measurement(fcns_fast, 512, [1,1,1] .* 16, "boundary size big")
    run_measurement(fcns_fast, 512, [1,1,1] .* 32, "boundary size big")
    run_measurement(fcns_fast, 512, [1,1,1] .* 64, "boundary size big")
end