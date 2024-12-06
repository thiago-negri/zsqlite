/// Numeric types available in SQLite C API
pub const NumericType = enum { int, int64, double };

pub fn getNumericType(comptime T: type) NumericType {
    switch (@typeInfo(T)) {
        .int => |info| {
            if (info.signedness == .unsigned) {
                @compileError("sqlite only supports signed numbers");
            }
            if (info.bits <= 32) {
                return .int;
            }
            if (info.bits > 64) {
                @compileError("sqlite only supports up to i64");
            }
            return .int64;
        },
        .comptime_int => {
            return .int64;
        },
        .float => |info| {
            if (info.bits > 64) {
                @compileError("sqlite only supports up to f64");
            }
            return .double;
        },
        .comptime_float => {
            return .double;
        },
        else => {
            @compileError("expecting a numeric type");
        },
    }
}

pub fn OptType(comptime flag: bool, t: type) type {
    return if (flag) t else void;
}

pub fn optValue(comptime flag: bool, v: anytype) OptType(flag, @TypeOf(v)) {
    return if (flag) v else {};
}
