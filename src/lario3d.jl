module lario3d

    export version
    hello(who::String) = "Hello, $who"

    include("read.jl")
    include("plasm.jl")
    include("surface.jl")
    include("representation.jl")
    include("import3d.jl")
    include("block.jl")
    include("sampledata.jl")
    include("io3d.jl")
    include("arr_fcn.jl")
    include("boundary_operator.jl")

    function version()
        return "0.0.2"
    end

end
