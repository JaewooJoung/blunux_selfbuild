#┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
#┃ 📁File      📄 build_id.jl                                                        ┃
#┃ 📙Brief     📝 ISO Build ID Generation Module for Blunux                          ┃
#┃ 📆LastDate  📍 2026-01-28                                                         ┃
#┃ 🏭License   📜 MIT License                                                        ┃
#┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
#=
Build ID generation module for Blunux ISO files.

Build ID format: XXXXXX (6-digit hex)
- First 2 digits: CRC-8 checksum based on date
- Next 4 digits: Build time (minutes since midnight in hex)

Example: blunux-C70366-korean-2024.02.29-x86_64.iso
=#

using Dates

"""
    calculate_date_checksum(dt::DateTime)::String

Calculate CRC-8 checksum from date components.
Uses polynomial: x^8 + x^2 + x + 1 (0x07)

Returns 2-digit uppercase hex string (00-FF).
"""
function calculate_date_checksum(dt::DateTime)::String
    year = Dates.year(dt)
    month = Dates.month(dt)
    day = Dates.day(dt)

    # Combine date components into a single byte for CRC calculation
    # XOR year (mod 256) with month shifted and day
    data = UInt8(year % 256) ⊻ UInt8((month << 4) & 0xFF) ⊻ UInt8(day)

    # CRC-8 calculation with polynomial 0x07
    crc = UInt8(0x00)
    for _ in 1:8
        if ((crc ⊻ data) & 0x80) != 0
            crc = ((crc << 1) & 0xFF) ⊻ 0x07
        else
            crc = (crc << 1) & 0xFF
        end
        data = (data << 1) & 0xFF
    end

    return uppercase(lpad(string(crc, base=16), 2, '0'))
end

"""
    convert_time_to_hex(dt::DateTime)::String

Convert time (hour:minute) to hex representation.
Calculates total minutes since midnight (0-1439) and converts to 4-digit hex.

Returns 4-digit uppercase hex string (0000-05A3).
"""
function convert_time_to_hex(dt::DateTime)::String
    hour = Dates.hour(dt)
    minute = Dates.minute(dt)

    # Total minutes since midnight (max 23*60+59 = 1439 = 0x59F)
    total_minutes = hour * 60 + minute

    return uppercase(lpad(string(total_minutes, base=16), 4, '0'))
end

"""
    generate_build_id(build_datetime::DateTime)::String

Generate a 6-digit hex build ID from build datetime.

Format: CC TTTT
- CC: 2-digit CRC-8 checksum of date
- TTTT: 4-digit hex of minutes since midnight

# Example
```julia
dt = DateTime(2024, 2, 29, 14, 30)
id = generate_build_id(dt)  # Returns something like "C70366"
```
"""
function generate_build_id(build_datetime::DateTime)::String
    checksum = calculate_date_checksum(build_datetime)
    time_hex = convert_time_to_hex(build_datetime)

    return checksum * time_hex
end

"""
    generate_build_id()::String

Generate build ID using current datetime.
"""
function generate_build_id()::String
    return generate_build_id(Dates.now())
end

"""
    generate_iso_filename(build_datetime::DateTime;
                          arch::String="x86_64",
                          language::String="korean")::String

Generate ISO filename with build ID.

# Arguments
- `build_datetime`: Build date and time
- `arch`: Architecture (default: "x86_64")
- `language`: Language variant (default: "korean")

# Returns
Filename like "blunux-C70366-korean-2024.02.29-x86_64.iso"
"""
function generate_iso_filename(build_datetime::DateTime;
                               arch::String="x86_64",
                               language::String="korean")::String
    build_id = generate_build_id(build_datetime)
    date_str = Dates.format(build_datetime, "yyyy.mm.dd")

    return "blunux-$(build_id)-$(language)-$(date_str)-$(arch).iso"
end

"""
    generate_iso_filename(; arch::String="x86_64", language::String="korean")::String

Generate ISO filename using current datetime.
"""
function generate_iso_filename(; arch::String="x86_64", language::String="korean")::String
    return generate_iso_filename(Dates.now(); arch=arch, language=language)
end

"""
    parse_build_id(build_id::String)::NamedTuple

Parse a build ID into its components.

# Returns
NamedTuple with:
- `checksum`: The 2-digit checksum
- `time_hex`: The 4-digit time hex
- `minutes`: Total minutes since midnight
- `hour`: Extracted hour (0-23)
- `minute`: Extracted minute (0-59)
"""
function parse_build_id(build_id::String)::NamedTuple
    if length(build_id) != 6
        error("Build ID must be exactly 6 characters, got: $(length(build_id))")
    end

    checksum = build_id[1:2]
    time_hex = build_id[3:6]

    minutes = parse(Int, time_hex, base=16)
    hour = div(minutes, 60)
    minute = mod(minutes, 60)

    return (checksum=checksum, time_hex=time_hex, minutes=minutes, hour=hour, minute=minute)
end

"""
    verify_build_id(build_id::String, expected_date::Date)::Bool

Verify that a build ID's checksum matches the expected date.

# Arguments
- `build_id`: 6-digit hex build ID
- `expected_date`: The date to verify against

# Returns
`true` if checksum matches, `false` otherwise.
"""
function verify_build_id(build_id::String, expected_date::Date)::Bool
    if length(build_id) != 6
        return false
    end

    checksum_part = build_id[1:2]

    # Calculate expected checksum from date (using midnight time)
    expected_checksum = calculate_date_checksum(DateTime(expected_date, Time(0, 0)))

    return uppercase(checksum_part) == expected_checksum
end

"""
    verify_iso_filename(filename::String)::NamedTuple

Parse and verify an ISO filename.

# Returns
NamedTuple with:
- `valid`: Whether the checksum is valid
- `build_id`: Extracted build ID
- `language`: Extracted language
- `date`: Extracted date
- `arch`: Extracted architecture
- `parsed_id`: Parsed build ID components
"""
function verify_iso_filename(filename::String)::NamedTuple
    # Pattern: blunux-XXXXXX-language-yyyy.mm.dd-arch.iso
    basename_part = replace(filename, r"\.iso$" => "")
    parts = split(basename_part, "-")

    if length(parts) < 5 || parts[1] != "blunux"
        error("Invalid ISO filename format: $filename")
    end

    build_id = String(parts[2])
    language = String(parts[3])
    date_str = String(parts[4])
    arch = String(parts[5])

    # Parse date
    date = Date(date_str, "yyyy.mm.dd")

    # Verify checksum
    valid = verify_build_id(build_id, date)

    # Parse build ID
    parsed_id = parse_build_id(build_id)

    return (valid=valid, build_id=build_id, language=language,
            date=date, arch=arch, parsed_id=parsed_id)
end

"""
    extract_build_info(filename::String)::String

Extract and display human-readable build info from ISO filename.
"""
function extract_build_info(filename::String)::String
    info = verify_iso_filename(filename)

    time_str = lpad(string(info.parsed_id.hour), 2, '0') * ":" *
               lpad(string(info.parsed_id.minute), 2, '0')

    status = info.valid ? "Valid" : "INVALID"

    return """
    ISO Filename: $filename
    ─────────────────────────────────
    Build ID:     $(info.build_id)
    Checksum:     $(info.parsed_id.checksum) ($status)
    Build Date:   $(info.date)
    Build Time:   $time_str
    Language:     $(info.language)
    Architecture: $(info.arch)
    """
end
