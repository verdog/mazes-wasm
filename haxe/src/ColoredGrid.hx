import bitmap.Color;

class ColoredGrid extends Grid {
    var distances:Distances;
    var max:Int;

    public function setDistances(distances:Distances) {
        this.distances = distances;
        max = distances.max().distance;
    }

    override function backgroundColorFor(cell:Cell):Null<bitmap.Color> {
        var distance = distances.getDistance(cell);
        if (distance == null) {
            return null;
        }
        var intensity = (max - distance) / max;

        var dark = Std.int(64 * intensity + 32);
        
        var buffer = 32;
        var bright = buffer + Std.int((255 - buffer) * intensity);
        
        return Color.create(bright, dark, bright, 255);
    }
}