class PolarCell extends Cell {
    public var cw:Cell;
    public var ccw:Cell;
    public var inward:Cell;
    public var outward(default, null):Array<Cell>;

    public function new(row, column) {
        super(row, column);
        outward = new Array<Cell>();
    }

    public override function neighbors() {
        var list = new Array<Cell>();
        if (cw != null) list.push(cw);
        if (ccw != null) list.push(ccw);
        if (inward != null) list.push(inward);
        list = list.concat(outward);

        return list;
    }
}
