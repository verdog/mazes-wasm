import Grid.GridIterator;

class BinaryTreeMaze extends Maze {
    public static function name() {
        return "btree";
    }
    
    public static function on(grid:Grid) {
        for (cell in new GridIterator(grid)) {
            var neighbors = [];
            if (cell.north != null) neighbors.push(cell.north);
            if (cell.east != null) neighbors.push(cell.east);

            var index = Std.random(neighbors.length);
            var neighbor = neighbors[index];

            if (neighbor != null) cell.link(neighbor);
        }
    }
}
