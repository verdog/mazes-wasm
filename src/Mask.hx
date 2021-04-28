import bitmap.IOUtil;
import bitmap.PNGBitmap;
import bitmap.BitmapIO;
using StringTools;

class Mask {
    public var rows(default, null):Int;
    public var cols(default, null):Int;

    private var bits:Array<Array<Bool>>;

    public function new(rows:Int, cols:Int) {
        this.rows = rows;
        this.cols = cols;

        bits = new Array<Array<Bool>>();
        bits.resize(rows);

        for (row in 0...rows) {
            bits[row] = new Array<Bool>();
            for (col in 0...cols) {
                bits[row][col] = true;
            }
        }
    }

    public static function fromTxt(filename:String) {
        var text = sys.io.File.getContent(filename);

        var lines = text.split("\n").filter(function f(l) return l.trim().length > 0);

        var rows = lines.length;
        var cols = lines[0].length;
        var mask = new Mask(rows, cols);

        for (row in 0...mask.rows) {
            for (col in 0...mask.cols) {
                mask.set(row, col, lines[row].charAt(col) == "X" ? false : true);
            }
        }

        return mask;
    }

    public static function fromPNG(filename:String) {
        var image = PNGBitmap.create(IOUtil.readFile(filename));
        var mask = new Mask(image.height, image.width);

        for (row in 0...mask.rows) {
            for (col in 0...mask.cols) {
                mask.set(row, col, image.get(col, row).b == 0 ? false : true);
            }
        }

        return mask;
    }

    public function at(row:Int, col:Int) {
        // make sure query is in bounds
        return row >= 0 && row < rows && col >= 0 && col < cols ? bits[row][col] : false;
    }

    public function set(row:Int, col:Int, bit:Bool) {
        if (!(row >= 0 && row < rows && col >= 0 && col < cols))
            return;
        bits[row][col] = bit;
    }

    public function count() {
        var count = 0;

        for (row in bits) {
            for (bit in row) {
                if (bit == true) count++;
            }
        }

        return count;
    }

    public function random_cell() {
        do {
            var row = Std.random(rows);
            var col = Std.random(cols);
            if (bits[row][col] == true) return [row, col];
        } while (true);
    }
}
