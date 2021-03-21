import haxe.ds.HashMap;

@:generic
function sampleArray<T>(array:Array<T>) {
    var idx = Std.random(array.length);
    return array[idx];
}

@:generic
function sampleMap<T, J>(map:Map<T, J>) {
    var keys = [];
    for (k in map.keys()) {
        keys.push(k);
    }
    return sampleArray(keys);
}

inline function intAbs(i:Int) {
    return if (i < 0) -i else i;
}
