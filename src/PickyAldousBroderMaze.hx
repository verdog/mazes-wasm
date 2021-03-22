import Useful.sampleArray;

// "picky" means that it won't walk on cells that are already visited unless it
// has to

class PickyAldousBroderMaze {
    public static function on(grid:Grid) {
        var cell = grid.randomCell();
        var unvisited = grid.size() - 1;

        while (unvisited > 0) {
            var possibleNeighbors = cell.neighbors();
            var neighbor = sampleArray(possibleNeighbors);

            while (neighbor.links().hasNext() && possibleNeighbors.length > 1) {
                // it's been visited... do we have another choice?
                possibleNeighbors.remove(neighbor);
                neighbor = sampleArray(possibleNeighbors);
            }

            if (possibleNeighbors.length == 1) {
                // trace("no choice... oh well...");
            }

            if (!neighbor.links().hasNext()) {
                cell.link(neighbor);
                unvisited--;
            }

            cell = neighbor;
        }
    }
}
