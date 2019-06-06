# This file is a part of LegendUpROOTIO.jl, licensed under the MIT License (MIT).


@enum EWFEncScheme EWFEncScheme_kUndefined=0 EWFEncScheme_kDouble=1 EWFEncScheme_kShort=2 EWFEncScheme_kDiffVarInt=3 EWFEncScheme_kUShort=4

@enum EWFType EWFType_kNoType=0 EWFType_kCharge=1 EWFType_kCurrent=2 EWFType_kADC=3 EWFType_kVoltage=4

@enum MGEventType MGEventType_kReal=0 MGEventType_kPulser=1 MGEventType_kMC=2 MGEventType_kUndefined=3 MGEventType_kBaseline=4

@enum EWaveformTag EWaveformTag_kNormal=0 EWaveformTag_kUnderflow=1 EWaveformTag_kOverflow=2 EWaveformTag_kUndefined=3 EWaveformTag_kCorrupted=4


struct MGTDataObjectContent{S<:AbstractString}
    tnamed::TNamedContent{S}
end

function Base.read(io::ROOTIOBuffer, ::Type{MGTDataObjectContent})
    ver = read(io, ROOTClassVersion)
    @assert ver.version == 2
    tnamed = read(io, TNamedContent)
    MGTDataObjectContent(tnamed)
end


function read_mgtclonesarray_header(io::ROOTIOBuffer)
    unknown_ver = read(io, ROOTClassVersion)
    if unknown_ver.version == -1
        # Interpretation of unknown_ver.version == -1 unclear
        @assert String(read(io.buffer, length("\xff\xffMGTClonesArray\0"))) == "\xff\xffMGTClonesArray\0"
    elseif (unknown_ver.version & 0xff00) == 0x8000
        # Interpretation of unknown_ver.version == 0x80.. unclear
        unknown_short = read(io, UInt16)
    else
        throw(ErrorException("Unexpected class version $(unknown_ver.version)"))
    end
    MGTClonesArray_wf_ver = read(io, ROOTClassVersion)
    @assert MGTClonesArray_wf_ver.version == 2
end


function _read_wfsamples_noenc(io::ROOTIOBuffer, T::Type{<:Real}, n::Int)
    samples = Vector{T}(undef, n)
    read!(io.buffer, samples)
    samples .= ntoh.(samples)
    samples
end


@inline function _read_vl_int(io::IO, T::Type{<:Unsigned})
    maxPos = 8 * sizeof(T)
    x::T = 0
    pos::Int = 0
    while true
        (pos >= maxPos) && throw(ErrorException("Overflow during decoding of variable-length encoded number."))
        b = read(io, UInt8)
        x = x | (T(b & 0x7f) << pos)
        if ((b & 0x80) == 0)
            return x
        else
            pos += 7
        end
    end
end

@inline _read_vl_int(io::IO, T::Type{<:Signed}) = _zigzagdec(_read_vl_int(io, unsigned(T)))

@inline _zigzagdec(x::Unsigned) = signed(xor((x >>> 1), (-(x & 1))))

function _read_wfsamples_diffvarint(io::ROOTIOBuffer, T::Type{<:Real}, n::Int)
    T = Int32
    buf = io.buffer
    x::T = 0
    samples = Vector{T}(undef, n)
    for i in eachindex(samples)
        x = _read_vl_int(buf, T) + x
        samples[i] = x
    end
    samples
end


function _read_wfsamples(io::ROOTIOBuffer, enc::EWFEncScheme, n::Integer)
    if enc == EWFEncScheme_kUndefined || enc == EWFEncScheme_kDouble
        _read_wfsamples_noenc(io, Float64, n)
    elseif (enc == EWFEncScheme_kShort)
        _read_wfsamples_noenc(io, Int16, n)
    elseif (enc == EWFEncScheme_kUShort)
        _read_wfsamples_noenc(io, UInt16, n)
    elseif (enc == EWFEncScheme_kDiffVarInt)
        _read_wfsamples_diffvarint(io, Int32, n)
    else
        throw(ErrorException("Sample encoding scheme $enc not supported"))
    end
end


function read_MGTWaveform(io::ROOTIOBuffer)
    MGTWaveform_ver = read(io, ROOTClassVersion)
    @assert MGTWaveform_ver.version == 5
    mgtdataobject = read(io, MGTDataObjectContent)

    fSampFreq = read(io, Float64)u"GHz"
    fTOffset = read(io, Float64)u"ns"
    fWFType = EWFType(read(io, Int32))
    fData_size = Int(read(io, UInt64))
    fWFEncScheme = EWFEncScheme(read(io, Int32))
    fData = _read_wfsamples(io, fWFEncScheme, fData_size)
    fID = read(io, Int32)

    unknown_byte = read(io, UInt8)
    @assert unknown_byte == 0x01

    time_units = u"ns"

    dt = Int32(uconvert(time_units, inv(fSampFreq)) / time_units) * time_units
    t0 = Int32(uconvert(time_units, fTOffset) / time_units) * time_units
    t_idxs = Int32(0):Int32(size(fData,1) - 1)
    t = t0 .+ t_idxs .* dt

    (
        ch = fID,
        wf = RDWaveform(fData, t),
    )
end


function read_tca_MGTWaveform(io::ROOTIOBuffer)
    read_mgtclonesarray_header(io)
    tcahdr = read(io, TClonesArrayHeader)
    @assert tcahdr.fName == "MGTWaveforms"
    @assert tcahdr.fClass == "MGTWaveform;5"

    wfdata_1 = read_MGTWaveform(io)
    ch = [wfdata_1.ch]
    wf_v = VectorOfVectors([wfdata_1.wf.v])
    wf_t = StructArray([wfdata_1.wf.t])

    for i in 2:tcahdr.nobjects
        wfdata = read_MGTWaveform(io)
        push!(ch, wfdata.ch)
        push!(wf_v, wfdata.wf.v)
        push!(wf_t, wfdata.wf.t)
    end

    TypedTables.Table(
        ch = ch,
        wf = StructArray{RDWaveform}((wf_v, wf_t))
    )
end


#=
# Possible digitizer data fields, depending on class:

bool fADCNMinusOneTriggerFlag;
bool fADCNPlusOneTriggerFlag;
bool fCFDCrossingOccurred;
bool fExternalTriggerFlag;
bool fIsInverted;
bool fIsMuVetoed;
bool fIsWrapModeEnabled;
bool fLEDCrossingSignIsNegative;
bool fPileupFlag;
bool fRetriggerFlag;
bool fTriggerFlag;
bool fTTCLTimeoutFlag;
double fClockFrequency;
double fEnergy;
int32_t fCFDPoint1;
int32_t fCFDPoint2;
int fEventNumber;
MGWaveformTag::EWaveformTag fWaveformTag;
size_t fPretrigger;
size_t fTriggerNumber;
uint32_t fNMaxChannels;
uint32_t fBitResolution;
uint32_t fBoardID;
uint32_t fEnergyInitial;
uint32_t fEnergyMax;
uint32_t fFastTriggerCounter;
uint32_t fID;
uint32_t fNChannels;
uint32_t fNofWrapSamples;
uint32_t fWrapStartIndex;
uint64_t fCFDTimeStamp;
uint64_t fIndex; 
uint64_t fTimeStamp;
unsigned int fDecimalTimeStamp;
unsigned int fMuVetoSample;
unsigned short fBoardSerialNumber; 
=#


# Use fnv1a32 hash of names for enum int values:


function read_MGTVDigitizerData(io::ROOTIOBuffer)
    MGTVDigitizerData_ver = read(io, ROOTClassVersion)
    @assert MGTVDigitizerData_ver.version == 1

    mgtdataobject = read(io, MGTDataObjectContent)

    fEnergy = read(io, Float64)
    fTimeStamp = read(io, UInt64)
    fID = read(io, Int32)
    fIndex = read(io, UInt64)

    (
        fEnergy = fEnergy,
        fTimeStamp = fTimeStamp,
        fID = fID,
        fIndex = fIndex,
    )
end


function read_GETVGERDADigitizerData(io::ROOTIOBuffer)
    GETVGERDADigitizerData_ver = read(io, ROOTClassVersion)
    @assert GETVGERDADigitizerData_ver.version == 2

    parent_content = read_MGTVDigitizerData(io)

    fNMaxChannels = UInt32(4) # meaningful?

    parent_content
end


function read_GETGERDADigitizerData(io::ROOTIOBuffer)
    GETGERDADigitizerData_ver = read(io, ROOTClassVersion)
    @assert GETGERDADigitizerData_ver.version == 1

    parent_content = read_GETVGERDADigitizerData(io)

    fClockFrequency = read(io, Float64)
    fEventNumber = read(io, Int32)
    fPretrigger = read(io, UInt64)
    fTriggerNumber = read(io, UInt64)
    fDecimalTimeStamp = read(io, UInt32)
    fIsMuVetoed = read(io, Bool)
    fMuVetoSample = read(io, UInt32)
    fIsInverted = read(io, Bool)
    fWaveformTag = EWaveformTag(read(io, Int32))

    unknown_byte = read(io, UInt8)
    @assert unknown_byte == 0x01

    content = (
        type = Val(:GETGERDADigitizerData),

        fClockFrequency = fClockFrequency,
        fEventNumber = fEventNumber,
        fPretrigger = fPretrigger,
        fTriggerNumber = fTriggerNumber,
        fDecimalTimeStamp = fDecimalTimeStamp,
        fIsMuVetoed = fIsMuVetoed,
        fMuVetoSample = fMuVetoSample,
        fIsInverted = fIsInverted,
        fWaveformTag = fWaveformTag,
    )
    merge(parent_content, content)
end


function read_tca_MGTVDigitizerData(io::ROOTIOBuffer)
    read_mgtclonesarray_header(io)
    tcahdr = read(io, TClonesArrayHeader)

    # ToDo: Support more digitizer classes

    @assert tcahdr.fName == "GETGERDADigitizerDatas"
    @assert tcahdr.fClass == "GETGERDADigitizerData;1"

    TypedTables.Table([read_GETGERDADigitizerData(io) for i in 1:tcahdr.nobjects])
end



function read_mgtevent(io::ROOTIOBuffer)
    MGTEvent_header = read(io, ROOTClassHeader)
    @assert MGTEvent_header.classname == "MGTEvent"

    version_MGTEvent = read(io, ROOTClassVersion)
    @assert version_MGTEvent.version == 9

    mgtdataobject = read(io, MGTDataObjectContent)

    fMGEventType = read(io, Int32)
    fETotal = read(io, Float64)
    fTime = read(io, Float64)

    fWaveforms = read_tca_MGTWaveform(io)

    fDigitizerData = read_tca_MGTVDigitizerData(io)


    fActiveID = let
        unknown_ver = read(io, ROOTClassVersion)
        @assert unknown_ver.version == -1
        @assert String(read(io.buffer, length("\xff\xffvector<bool>\0"))) == "\xff\xffvector<bool>\0"
        read(io, Vector{Bool})
    end

    fUseAuxWaveformArray = read(io, Bool)


    fAuxWaveforms = read_tca_MGTWaveform(io)

    fEventNumber = read(io, Int32)

    (
        fMGEventType = MGEventType(fMGEventType),
        fETotal = fETotal,
        fTime = fTime,
        fWaveforms = fWaveforms,
        fDigitizerData = fDigitizerData,
        fActiveID = fActiveID,
        fUseAuxWaveformArray = fUseAuxWaveformArray,
        fAuxWaveforms = fAuxWaveforms,
        fEventNumber = fEventNumber,
    )
end


function raw2mgtevent(evt_raw::UpROOT.OpaqueObject{:MGTEvent})
    io = ROOTIOBuffer(evt_raw.data)
    event = read_mgtevent(io)
    @assert eof(io)
    event
end




const _dict_EWaveformTag2daqflags = IdDict(
    EWaveformTag_kNormal => daq_noflags,
    EWaveformTag_kUnderflow => daq_underflow,
    EWaveformTag_kOverflow => daq_overflow,
    # EWaveformTag_kUndefined => ??,
    EWaveformTag_kCorrupted => daq_corrupt,
)

mgdo2legend(x::EWaveformTag) = _dict_EWaveformTag2daqflags[x]


const _dict_MGEventType2EventType = IdDict(
    MGEventType_kReal => evt_real,
    MGEventType_kPulser => evt_pulser,
    MGEventType_kMC => evt_mc,
    MGEventType_kUndefined => evt_undef,
    MGEventType_kBaseline => evt_baseline,
)

mgdo2legend(x::MGEventType) = _dict_MGEventType2EventType[x]


function mgdo2legend(::Val{:GETGERDADigitizerData}, x::TypedTables.Table)
    TypedTables.Table(
        ch = x.fID,

        daqclk = x.fTimeStamp,
        index = x.fIndex, # Meaning?

        psa_energy = x.fEnergy,

        # ignore = x.fClockFrequency, # better kept in metadata/config files
        daqevtno = x.fEventNumber, # Meaning?
        # ignore = x.fPretrigger, # use in waveform
        trigno = x.fTriggerNumber, # Meaning?
        muveto = x.fIsMuVetoed,
        muveto_sample = x.fMuVetoSample, # Meaning?
        decimal_timestamp = x.fDecimalTimeStamp, # Meaning?
        inverted = x.fIsInverted, # 
        #flags = mgdo2legend.(x.fWaveformTag),
    )
end


function mgdo2legend(evt::NamedTuple)
    @argcheck evt.fWaveforms.ch == evt.fDigitizerData.fID
    @argcheck isempty(evt.fAuxWaveforms) || evt.fWaveforms.ch == evt.fAuxWaveforms.ch
    @argcheck evt.fETotal ≈ sum(evt.fDigitizerData.fEnergy)
    # EWFType_kADC

    digidata = mgdo2legend(eltype(evt.fDigitizerData.type)(), evt.fDigitizerData)

    n = length(eachindex(digidata))

    evtdata = (
        evttype = fill(mgdo2legend(evt.fMGEventType), n),
        unixtime = fill(evt.fTime, n),
        evtno = fill(evt.fEventNumber, n), # LEGEND daq files will typically not have this
        # evt.fActiveID, # better kept in metadata/config files
        # evt.fETotal # Don't need to store this
        # evt.fUseAuxWaveformArray # Don't need to store this
    )

    wfdata = (
        waveform_lf = evt.fWaveforms.wf,
        waveform_hf = evt.fAuxWaveforms.wf,
    )

    TypedTables.Table(merge(evtdata, Tables.columns(digidata), wfdata))
end


function mgdo2legend(events::AbstractVector{<:NamedTuple})
    tbl = mgdo2legend(deepcopy(events[firstindex(events)]))
    for i in (firstindex(events) + 1):lastindex(events)
        append!(tbl, mgdo2legend(events[i]))
    end
    tbl
end
