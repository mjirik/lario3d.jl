println("Starting...")
@info "Starting..."
time_start = time()
# using Revise
# using ExSu
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--block_size"
            help = "Block size given by scalar Int"
			arg_type = Int
			default = 64
        "--input_path", "-i"
            help = "Input path"
			default = nothing
        "--output_path", "-o"
            help = "output path"
			default = "."
        "--input_path_in_datasets", "-d"
            help = "Input path relative to Io3d.jl dataset path"
			default = nothing
        "--threshold"
            help = "another option with an argument"
            arg_type = Int
            default = 7000
        "--stepz"
            help = "Every stepz-th voxel in z-axis is readed"
            arg_type = Int
			default = 1
        "--stepxy"
            help = "Every stepxy-th voxel in xy-axis is readed"
            arg_type = Int
			default = 1
        "--crop"
            help = "Integer number describing the size of crop of input volume for all axes."
            arg_type = Int
			default = nothing
        "--output_csv_file"
            help = "Path to outpu CSV file"
            default = "exp_surface_extraction_times.csv"
        "--label"
            help = "label used in output filename"
            default = "data"
        "--taubin_lambda"
            help = "Taubin smoothing parameter. lambda=0.33, mu=-0.34"
            arg_type = Float64
			default = 0.33
        "--taubin_mu"
            help = "Taubin smoothing parameter. lambda=0.33, mu=-0.34"
            arg_type = Float64
			default = -0.34
        "--taubin_n"
            help = "Taubin smoothing parameter. Number of iterations "
            arg_type = Int
			default = 10
        "--n_procs"
            help = "Number of required CPU-cores"
            arg_type = Int
			default = 4
        "--show"
            help = "Show 3D visualization"
            action = :store_true
        "--skip_smoothing"
            help = "Skip smoothing procedure"
            action = :store_true
            # action = :store_true
        # "arg1"
        #     help = "a positional argument"
        #     required = true
    end

    return parse_args(s)
end
args = parse_commandline()

# println("args: $(args)")
# println(args["threshold"])
# exit()

using Test
using Logging
using SparseArrays
using ExSu
using Io3d
using JLD2
using ViewerGL
@info "Distributed init..."
using Distributed
if nprocs() == 1
    addprocs(args["n_procs"]-1)
end
block_size_scalar = args["block_size"]


using LarSurf
# @everywhere using LarSurf


# fn = "exp_surface_extraction_ircad_times.csv"
output_csv_file = args["output_csv_file"]

@info "before everywhere using"
@info "time from start: $(time()-time_start) [s]"
# using Plasm
# @everywhere using LarSurf
# @everywhere using Distributed

@info "after everywhere using, time from start: $(time()-time_start) [s]"


# data_id = 1
show = false
taubin = true
# taubin_n = 5
# taubin_lambda = 0.4
# taubin_mu = -0.2

crop_px = args["crop"]
if crop_px == nothing
	do_crop = false
else
	do_crop = true
	cropx = crop_px
	cropy = crop_px
	cropz = crop_px
end
# stepxy = 4
# block_size = [128, 128, 128]
# block_size = [128, 128, 128]
# block_size = [32, 32, 32]
# data_size1 = 128
# data_size1 = 256
# data_size1 = 512

# -------------------------------------------------------------------


data = LarSurf.Experiments.report_init_row(@__FILE__)
LarSurf.set_time_data(data)

# data["nprocs"] = nprocs()
# data["fcn"] = String(Symbol(fcni))

data["using done"] = time()-time_start
# segmentation = LarSurf.data234()
@info "Generate data..."
@info "time from start: $(time() - time_start) [s]"
# pth = Io3d.datasets_join_path("medical/orig/3Dircadb1.$data_id/MASKS_DICOM/liver")

# for mask_label in mask_labels

	if args["input_path"] == nothing
		if args["input_path_in_datasets"] == nothing
			pth = Io3d.datasets_join_path("medical/orig/jatra_mikro_data/Nejlepsi_rozliseni_nevycistene")
			pth = Io3d.datasets_join_path("medical/processed/corrosion_cast/nrn10.pklz")
		else
			pth = Io3d.datasets_join_path(args["input_path_in_datasets"])
		end

	else
		pth = args["input_path"]
	end





# V1 is V or Vs accoring to smoothing parameter
V1, FVtri = LarSurf.Experiments.experiment_make_surf_extraction_and_smoothing(
	pth;
	output_path=args["output_path"],
	threshold=args["threshold"],
	mask_label = args["label"],
	stepz = args["stepz"],
	stepxy = args["stepxy"],
	do_crop=do_crop, cropx=cropx, cropy=cropy, cropz=cropz,
	block_size_scalar=block_size_scalar, data=data, time_start=time_start,
	output_csv_file = output_csv_file,
	taubin=taubin,
	taubin_lambda = args["taubin_lambda"],
	taubin_mu = args["taubin_mu"],
	taubin_n = args["taubin_n"],
	smoothing= !args["skip_smoothing"]
)
show=args["show"]
if show
	@info "ViewerGL init ..."
	using ViewerGL
	ViewerGL.VIEW([
	    ViewerGL.GLGrid(V1, FVtri, ViewerGL.Point4d(1, 0, 1, 0.1))
		ViewerGL.GLAxis(ViewerGL.Point3d(-1, -1, -1),ViewerGL.Point3d(1, 1, 1))
	])
end