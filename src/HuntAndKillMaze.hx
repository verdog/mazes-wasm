import Useful.sampleArray;

class HuntAndKillMaze extends Maze {
    public static function name() {
        return "huntandkill";
    }
    
    public static function on(grid:Grid) {
        var current = grid.randomCell();

        while (current != null) {
            var unvisited 
                = current.neighbors().filter(function(c) return c.links().hasNext() == false);
            
            if (unvisited.length != 0) {
                var neighbor = sampleArray(unvisited);
                current.link(neighbor);
                current = neighbor;
            } else {
                current = null;
                
                // no unvisited neighbors  
                for (cell in grid) {
                    var visited = 
                        cell.neighbors().filter(function(c) return c.links().hasNext());
                    if (!cell.links().hasNext() && visited.length != 0) {
                        current = cell;

                        var neighbor = sampleArray(visited);
                        current.link(neighbor);

                        break;
                    }
                }
            }
        }
    }
}