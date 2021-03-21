function sampleArray(array) {
    var idx = Std.random(array.length);
    return array[idx];
}

inline function intAbs(i:Int) {
    return if (i < 0) -i else i;
}
