# This file is a part of LegendUpROOTIO.jl, licensed under the MIT License (MIT).

__precompile__(true)

module LegendUpROOTIO

using ArraysOfArrays
using ElasticArrays
using LegendDataTypes
using RadiationDetectorSignals
using StaticArrays
using Tables
using Unitful
using UpROOT

import HDF5
import TypedTables

using LegendDataTypes: readdata, writedata, getunits, setunits!, units_from_string, units_to_string

using RadiationDetectorSignals: RealQuantity, ArrayOfDims, AosAOfDims, SArrayOfDims,
    recursive_ndims

include("mgdo.jl")

end # module
