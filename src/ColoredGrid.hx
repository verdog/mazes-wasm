import bitmap.Color;

class ColoredGrid extends Grid {
    var distances:Distances;
    var max:Int;

    public function setDistances(distances:Distances) {
        this.distances = distances;
        max = distances.max().distance;
    }

    override function backgroundColorFor(cell:Cell) {
        var distance = distances.getDistance(cell);
        if (distance == null) {
            return null;
        }
        var intensity = (max - distance) / max;
        var dark = Std.int(255 * intensity);
        var bright = 128 + Std.int(127 * intensity);
        return Color.create(dark, bright, dark, 255);
    }
}