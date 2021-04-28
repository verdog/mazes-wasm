class MaskedGrid extends ColoredGrid {
    public var mask(default, null):Mask;
    
    public function new(mask:Mask) {
        this.mask = mask;
        super(mask.rows, mask.cols);
    }

    public override function prepareGrid():Array<Array<Cell>> {
        trace("preparing masked grid...");

        var a = new Array<Array<Cell>>();

        a.resize(rows);

        for (row in 0...rows) {
            a[row] = new Array<Cell>();
            a[row].resize(columns);
            for (col in 0...columns) {
                if (mask.at(row, col) == true) {
                    a[row][col] = new Cell(row, col);
                }
            }
        }

        return a;
    }

    public override function randomCell():Cell {
        var location = mask.random_cell();
        return at(location[0], location[1]);
    }

    public override function size():Int {
        return mask.count();
    }
}