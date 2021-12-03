# This file is a part of LegendUpROOTIO.jl, licensed under the MIT License (MIT).

module LegendUpROOTIO

using ArgCheck
using ArraysOfArrays
using ElasticArrays
using LegendDataTypes
using RadiationDetectorSignals
using StaticArrays
using StructArrays
using Tables
using Unitful
using UpROOT

import TypedTables

using LegendDataTypes: readdata, writedata, getunits, setunits!, units_from_string, units_to_string

using RadiationDetectorSignals: RealQuantity, ArrayOfDims, AosAOfDims, SArrayOfDims,
    recursive_ndims

using UpROOT: ROOTIOBuffer, ROOTClassHeader, ROOTClassVersion, TObjectContent, TNamedContent,
    TClonesArrayHeader, kByteCountMask


include("mgdo.jl")

end # module
