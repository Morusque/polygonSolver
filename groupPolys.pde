
void setup() {
  size(1920, 1080);
  
  // create a list of segments
  ArrayList<PVector[]> segments = new ArrayList<>();
  for (int i = 0; i < 100; i++) segments.add(new PVector[] {new PVector((i * 23) % width, (i * 27) % height), new PVector((i * 30) % width, (i * 32) % height)});
  
  // convert the segments into a list of smallest closed non-overlapping polygons
  ArrayList<PVector[]> shapes = new SegmentProcessor().convertSegmentsToShapes(segments);
  
  // draw the result
  background(0);
  for (PVector[] s : segments) {
    stroke(0xFF);
    line(s[0].x, s[0].y, s[1].x, s[1].y);
  }
  for (PVector[] s : shapes) {
    noStroke();
    fill(color(random(0x100), random(0x100), random(0x100)));
    beginShape();
    for (PVector sp : s) vertex(sp.x, sp.y);
    endShape();
  }
  
}
