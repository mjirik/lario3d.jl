println("First line of the script")
time_start = time()
using Distributed
if nprocs() == 1
    addprocs(3)
end
# using Revise
using Test
using Logging
using SparseArrays

@info "time from start: $(time()-time_start) [s]"
# using Plasm
@everywhere using LarSurf
@everywhere using Distributed

block_size = [64, 64, 64]
data_size1 = 256

# segmentation = LarSurf.data234()
@info "Generate data..."
@info "time from start: $(time()-time_start) [s]"
segmentation = LarSurf.generate_cube(data_size1; remove_one_pixel=true)

@info "Setup..."
@info "time from start: $(time()-time_start) [s]"
setup_time = @elapsed LarSurf.lsp_setup(block_size)
println("setup time: $setup_time")
@info "time from start: $(time()-time_start) [s]"
# for wid in workers()
#     # println("testing on $wid")
#     ftr = @spawnat wid LarSurf._single_boundary3
#     @test fetch(ftr) != nothing
# end

@debug "Setup done"
val, tm, mem, gc = @timed LarSurf.lsp_get_surface(segmentation)
println("Total time: $tm")

@info "time from start: $(time()-time_start) [s]"

# Plasm.view(val)