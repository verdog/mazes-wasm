class Distances {
    private var root:Cell;
    private var cells:Map<Cell, Int>;
    
    public function new(root:Cell) {
        this.root = root;
        cells = new Map<Cell, Int>();
        cells[root] = 0;
    }

    public function getDistance(cell:Cell) {
        return cells[cell];
    }

    public function setDistance(cell:Cell, dist:Int) {
        cells[cell] = dist;
    }

    public function getCells() {
        return cells.keys();
    }

    public function pathTo(goal:Cell) {
        var current = goal;

        var breadcrumbs = new Distances(root);
        breadcrumbs.setDistance(current, getDistance(current));

        while (current != root) {
            for (neighbor in current.links()) {
                if (cells[neighbor] < cells[current]) {
                    breadcrumbs.setDistance(neighbor, cells[neighbor]);
                    current = neighbor;
                    break;
                }
            }
        }

        return breadcrumbs;
    }

    public function max() {
        var max_distance = 0;
        var max_cell = root;

        for (cell => distance in cells) {
            if (distance > max_distance) {
                max_cell = cell;
                max_distance = distance;
            }
        }

        return {cell: max_cell, distance: max_distance};
    }
}
