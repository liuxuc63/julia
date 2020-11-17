# This file is a part of Julia. License is MIT: https://julialang.org/license

Core.include(Main, "Base.jl")

using .Base

# Set up Main module
import Base.MainInclude: eval, include

# Ensure this file is also tracked
pushfirst!(Base._included_files, (@__MODULE__, joinpath(@__DIR__, "Base.jl")))
pushfirst!(Base._included_files, (@__MODULE__, joinpath(@__DIR__, "sysimg.jl")))

# set up depot & load paths to be able to find stdlib packages
@eval Base creating_sysimg = true
Base.init_depot_path()
Base.init_load_path()

if Base.is_primary_base_module
# load some stdlib packages but don't put their names in Main
let
    # Stdlibs sorted in dependency, then alphabetical, order by contrib/print_sorted_stdlibs.jl
    stdlibs = [
        # No dependencies
        :ArgTools,
        :Artifacts,
        :Base64,
        :CRC32c,
        :FileWatching,
        :Libdl,
        :Logging,
        :Mmap,
        :MozillaCACerts_jll,
        :NetworkOptions,
        :SHA,
        :Serialization,
        :Sockets,
        :Unicode,

        # 1-depth packages
        :CompilerSupportLibraries_jll,
        :DelimitedFiles,
        :GMP_jll,
        :LibCURL_jll,
        :LibOSXUnwind_jll,
        :LibUV_jll,
        :LibUnwind_jll,
        :LinearAlgebra,
        :Markdown,
        :MbedTLS_jll,
        :OpenLibm_jll,
        :PCRE2_jll,
        :Printf,
        :Random,
        :Tar,
        :Zlib_jll,
        :dSFMT_jll,
        :libLLVM_jll,
        :nghttp2_jll,
        :p7zip_jll,

        # 2-depth packages
        :Dates,
        :Distributed,
        :Future,
        :InteractiveUtils,
        :LibCURL,
        :LibGit2,
        :LibSSH2_jll,
        :MPFR_jll,
        :OpenBLAS_jll,
        :Profile,
        :SparseArrays,
        :UUIDs,

        # 3-depth packages
        :Downloads,
        :LibGit2_jll,
        :REPL,
        :SharedArrays,
        :Statistics,
        :SuiteSparse,
        :SuiteSparse_jll,
        :TOML,
        :Test,

        # 4-depth packages
        :Pkg,

        # 5-depth packages
        :LazyArtifacts,
    ]
    maxlen = reduce(max, textwidth.(string.(stdlibs)); init=0)

    tot_time_stdlib = 0.0
    # use a temp module to avoid leaving the type of this closure in Main
    m = Module()
    GC.@preserve m begin
        print_time = @eval m (mod, t) -> (print(rpad(string(mod) * "  ", $maxlen + 3, "─"));
                                          Base.time_print(t * 10^9); println())
        print_time(Base, (Base.end_base_include - Base.start_base_include) * 10^(-9))

        Base._track_dependencies[] = true
        tot_time_stdlib = @elapsed for stdlib in stdlibs
            tt = @elapsed Base.require(Base, stdlib)
            print_time(stdlib, tt)
        end
        for dep in Base._require_dependencies
            dep[3] == 0.0 && continue
            push!(Base._included_files, dep[1:2])
        end
        empty!(Base._require_dependencies)
        Base._track_dependencies[] = false

        print_time("Stdlibs total", tot_time_stdlib)
    end

    # Clear global state
    empty!(Core.ARGS)
    empty!(Base.ARGS)
    empty!(LOAD_PATH)
    @eval Base creating_sysimg = false
    Base.init_load_path() # want to be able to find external packages in userimg.jl

    ccall(:jl_clear_implicit_imports, Cvoid, (Any,), Main)
    tot_time_userimg = @elapsed (isfile("userimg.jl") && Base.include(Main, "userimg.jl"))

    tot_time_base = (Base.end_base_include - Base.start_base_include) * 10.0^(-9)
    tot_time = tot_time_base + tot_time_stdlib + tot_time_userimg

    println("Sysimage built. Summary:")
    print("Total ─────── "); Base.time_print(tot_time               * 10^9); print(" \n");
    print("Base: ─────── "); Base.time_print(tot_time_base          * 10^9); print(" "); show(IOContext(stdout, :compact=>true), (tot_time_base          / tot_time) * 100); println("%")
    print("Stdlibs: ──── "); Base.time_print(tot_time_stdlib * 10^9); print(" "); show(IOContext(stdout, :compact=>true), (tot_time_stdlib / tot_time) * 100); println("%")
    if isfile("userimg.jl")
    print("Userimg: ──── "); Base.time_print(tot_time_userimg       * 10^9); print(" "); show(IOContext(stdout, :compact=>true), (tot_time_userimg       / tot_time) * 100); println("%")
    end

    empty!(LOAD_PATH)
    empty!(DEPOT_PATH)
end

empty!(Base.TOML_CACHE.d)
Base.TOML.reinit!(Base.TOML_CACHE.p, "")
@eval Sys begin
    BINDIR = ""
    STDLIB = ""
end
end
