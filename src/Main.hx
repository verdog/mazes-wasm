import Image.gridToPNG;

class Main {
	static function main() {
		var g = new Grid(64, 64);
		// SidewinderMaze.on(g);
		BinaryTreeMaze.on(g);
		g.print();
		gridToPNG(g);
	}
}
