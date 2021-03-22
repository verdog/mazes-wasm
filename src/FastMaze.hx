import Useful.sampleMap;
import haxe.ds.HashMap;
import Useful.sampleArray;
import Grid.GridIterator;
// attempt to combine wilson and aldous-broder to use each when they are fastest

class FastMaze extends Maze {
    public static function name() {
        return "fast";
    }
    
    public static function on(grid:Grid) {
        // trace("Generating maze... (FastMaze)");
        
        // start with aldous-broder
        var unvisited = new Map<Cell, Bool>();
        
        for (cell in new GridIterator(grid)) {
            unvisited.set(cell, true);
        }

        var cell = sampleMap(unvisited);
        unvisited.remove(cell);

        var numUnvisited = grid.size() - 1;
        var switchThreshold = Std.int(grid.size()/64);

        var next_start = cell;

        while (numUnvisited > switchThreshold) {
            var neighbor = sampleArray(cell.neighbors());

            if (!neighbor.links().hasNext()) {
                cell.link(neighbor);
                unvisited.remove(neighbor);
                numUnvisited--;
            }

            cell = neighbor;
            next_start = neighbor;
        }

        // finish with wilson
        var cell = next_start;

        while (numUnvisited > 0) {
            var cell = sampleMap(unvisited);
            var path = [cell];

            while (unvisited.exists(cell)) {
                cell = sampleArray(cell.neighbors());
                var position = path.indexOf(cell);

                if (position != -1) {
                    path = path.slice(0, position + 1);
                } else {
                    path.push(cell);
                }
            }

            for (index in 0...path.length - 1) {
                path[index].link(path[index + 1]);
                unvisited.remove(path[index]);
                numUnvisited--;
            }
        }
    }
}
