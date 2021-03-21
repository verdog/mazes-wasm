class DistanceGrid extends Grid {
    public var distances:Distances;

    override function contentsOf(cell:Cell) {
        var chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";

        if (distances != null && distances.getDistance(cell) != null) {
            return '${chars.charAt(distances.getDistance(cell))}';
        } else {
            return " ";
        }
    }
}
