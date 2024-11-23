 //<>//
static class SegmentProcessor {

  // Static factory method for one-off usage
  public static ArrayList<PVector[]> processSegments(ArrayList<PVector[]> inputSegments) {
    return new SegmentProcessor().convertSegmentsToShapes(inputSegments);
  }

  // Convert raw input segments into shapes and return as ArrayList<PVector[]>
  public ArrayList<PVector[]> convertSegmentsToShapes(ArrayList<PVector[]> inputSegments) {

    ArrayList<Segment> segments = new ArrayList<Segment>();
    ArrayList<ArrayList<Vertex>> shapes = new ArrayList<ArrayList<Vertex>>(); // Stores detected polygons as lists of vertices
    ArrayList<Vertex> vertices = new ArrayList<Vertex>(); // All vertices used in the system

    for (PVector[] inputSegment : inputSegments) {
      segments.add(new Segment(inputSegment[0], inputSegment[1], null, null));
    }

    intersectSegments(segments, vertices); // Pass local state to helper methods
    for (Segment s : segments) s.informVertex();
    for (Vertex v : vertices) v.trimDeadEnds();
    extractPolygons(shapes, vertices);

    // Convert polygons into ArrayList<PVector[]>
    ArrayList<PVector[]> shapeVectors = new ArrayList<>();
    for (ArrayList<Vertex> shape : shapes) {
      PVector[] verticesArray = new PVector[shape.size()];
      for (int i = 0; i < shape.size(); i++) {
        verticesArray[i] = shape.get(i).pos;
      }
      shapeVectors.add(verticesArray);
    }

    return shapeVectors;
  }

  // Identify and process intersections between segments
  void intersectSegments(ArrayList<Segment> segments, ArrayList<Vertex> vertices) {
    boolean stillCutting = true;

    while (stillCutting) {
      ArrayList<Segment> segmentsToAdd = new ArrayList<>();
      ArrayList<Segment> segmentsToDelete = new ArrayList<>();

      for (Segment sA : segments) {
        for (Segment sB : segments) {
          // Skip redundant comparisons and processed segments
          if (sA != sB && !segmentsToDelete.contains(sA) && !segmentsToDelete.contains(sB)) {
            processIntersection(sA, sB, segmentsToAdd, segmentsToDelete, vertices);
          }
        }
      }

      segments.addAll(segmentsToAdd); // Add newly created segments
      segments.removeAll(segmentsToDelete); // Remove processed segments
      stillCutting = !segmentsToAdd.isEmpty(); // Stop if no new segments were added
    }
  }

  // Process the intersection of two segments, splitting them if necessary
  void processIntersection(Segment sA, Segment sB, ArrayList<Segment> segmentsToAdd, ArrayList<Segment> segmentsToDelete, ArrayList<Vertex> vertices) {

    float vertexEpsilon = 0.001; // how close two vertices have to be for the algorithm to consider them equal

    PVector intersection = lineSegmentIntersection(sA.a, sA.b, sB.a, sB.b);

    if (intersection != null && !shareAVertex(sA, sB)) {

      Vertex v = new Vertex();
      v.pos = intersection.copy();

      boolean newVertex = true;
      for (Vertex v2 : vertices) {
        if (PVector.dist(v.pos, v2.pos)<vertexEpsilon) {
          v=v2;
          newVertex = false;
        }
      }

      // Create new segments split at the intersection point
      segmentsToAdd.add(new Segment(sA.a, v.pos, sA.aConnected, v));
      segmentsToAdd.add(new Segment(sA.b, v.pos, sA.bConnected, v));
      segmentsToAdd.add(new Segment(sB.a, v.pos, sB.aConnected, v));
      segmentsToAdd.add(new Segment(sB.b, v.pos, sB.bConnected, v));

      segmentsToDelete.add(sA);
      segmentsToDelete.add(sB);
      if (newVertex) vertices.add(v); // Add the new vertex to the global list
    }
  }

  // Find the next vertex in a shape, ensuring a closed polygon
  Vertex nextVertexAfter(Vertex a, Vertex b) {
    // Handle unexpected or edge cases with b.next
    if (b.next.isEmpty()) return null; // No connections, invalid vertex
    if (b.next.size() == 1) return null; // Dead-end vertex, unexpected in a polygon
    if (b.next.size() == 2) { // Degenerate "flat" polygon
      if (b.next.get(0) == b.next.get(1)) {
        return b.next.get(0); // Return the single valid connection
      }
    }
    Vertex bestC = null;
    boolean stop = false;
    for (int j = 0; !stop; j = (j + 1) % b.next.size()) {// Main loop to find the next vertex
      Vertex c = b.next.get(j);
      if (c == a) {
        if (bestC != null) stop = true; // Stop once we have found the next valid vertex
      } else {
        bestC = c;
      }
    }
    return bestC;
  }

  // Extract polygons from connected segments and vertices
  void extractPolygons(ArrayList<ArrayList<Vertex>> shapes, ArrayList<Vertex> vertices) {

    for (Vertex startingVertex : vertices) {
      for (int i = 0; i < startingVertex.next.size(); i++) {
        ArrayList<Vertex> verticesInShape = new ArrayList<>();
        Vertex a = startingVertex;
        Vertex b = a.next.get(i);
        verticesInShape.add(a);
        verticesInShape.add(b);

        boolean shapeDone = false;
        while (!shapeDone) {
          if (b.next.size() >= 2) {
            Vertex c = nextVertexAfter(a, b);
            if (c == startingVertex) {
              shapeDone = true;
              if (!shapeAlreadyExists(verticesInShape, shapes) && !isClockwise(verticesInShape)) {
                shapes.add(new ArrayList<>(verticesInShape));
              }
            } else {
              verticesInShape.add(c);
              a = b;
              b = c;
            }
          } else {
            shapeDone = true; // End of the shape
          }
        }
      }
    }
  }

  // Check if two segments share a vertex
  boolean shareAVertex(Segment sA, Segment sB) {
    if (sA.aConnected != null && sB.aConnected != null && sA.aConnected == sB.aConnected) return true;
    if (sA.bConnected != null && sB.aConnected != null && sA.bConnected == sB.aConnected) return true;
    if (sA.aConnected != null && sB.bConnected != null && sA.aConnected == sB.bConnected) return true;
    if (sA.bConnected != null && sB.bConnected != null && sA.bConnected == sB.bConnected) return true;
    return false;
  }

  // Check if a polygon already exists in the shapes list
  boolean shapeAlreadyExists(ArrayList<Vertex> verticesHere, ArrayList<ArrayList<Vertex>> shapes) {
    for (ArrayList<Vertex> existingShape : shapes) {
      if (existingShape.size() != verticesHere.size()) continue;
      boolean isDuplicate = true;
      for (Vertex v : verticesHere) {
        if (!existingShape.contains(v)) isDuplicate = false;
      }
      for (Vertex v : existingShape) {
        if (!verticesHere.contains(v)) isDuplicate = false;
      }
      if (isDuplicate) return true;
    }
    return false;
  }

  // Check if a polygon is clockwise
  boolean isClockwise(ArrayList<Vertex> vertices) {
    float sum = 0;
    int n = vertices.size();

    for (int i = 0; i < n; i++) {
      PVector current = vertices.get(i).pos;
      PVector next = vertices.get((i + 1) % n).pos; // Wrap around to the first vertex
      sum += (next.x - current.x) * (next.y + current.y);
    }
    return sum > 0;
  }

  // Compute intersection of two line segments (null if no intersection)
  PVector lineSegmentIntersection(PVector p1A, PVector p1B, PVector p2A, PVector p2B) {
    if (Math.max(p1A.x, p1B.x) < Math.min(p2A.x, p2B.x) ||
      Math.min(p1A.x, p1B.x) > Math.max(p2A.x, p2B.x) ||
      Math.max(p1A.y, p1B.y) < Math.min(p2A.y, p2B.y) ||
      Math.min(p1A.y, p1B.y) > Math.max(p2A.y, p2B.y)) {
      return null; // Bounding boxes do not overlap
    }

    PVector s1 = new PVector(p1B.x - p1A.x, p1B.y - p1A.y);
    PVector s2 = new PVector(p2B.x - p2A.x, p2B.y - p2A.y);

    float s = (-s1.y * (p1A.x - p2A.x) + s1.x * (p1A.y - p2A.y)) / (-s2.x * s1.y + s1.x * s2.y);
    float t = ( s2.x * (p1A.y - p2A.y) - s2.y * (p1A.x - p2A.x)) / (-s2.x * s1.y + s1.x * s2.y);

    if (s >= 0 && s <= 1 && t >= 0 && t <= 1)
      return new PVector(p1A.x + (t * s1.x), p1A.y + (t * s1.y));

    return null; // No intersection
  }

  // Segment class represents a line segment
  class Segment {
    PVector a, b;
    Vertex aConnected = null;
    Vertex bConnected = null;

    Segment(PVector a, PVector b, Vertex aConnected, Vertex bConnected) {
      this.a = a.copy();
      this.b = b.copy();
      this.aConnected = aConnected;
      this.bConnected = bConnected;
    }

    void informVertex() {
      if (aConnected != null && !aConnected.connected.contains(this)) {
        aConnected.connected.add(this);
        aConnected.isA.add(true);
      }
      if (bConnected != null && !bConnected.connected.contains(this)) {
        bConnected.connected.add(this);
        bConnected.isA.add(false);
      }
    }
  }

  // Vertex class represents a point and its connections
  class Vertex {
    PVector pos;
    ArrayList<SegmentProcessor.Segment> connected = new ArrayList<>();
    ArrayList<Boolean> isA = new ArrayList<>();
    ArrayList<Float> angle = new ArrayList<>();
    ArrayList<Vertex> next = new ArrayList<>();

    void trimDeadEnds() {
      // Remove dead ends from connected and isA lists
      for (int i = connected.size() - 1; i >= 0; i--) {
        Vertex otherEnd = isA.get(i) ? connected.get(i).bConnected : connected.get(i).aConnected;
        if (otherEnd == null) {
          connected.remove(i);
          isA.remove(i);
        }
      }

      // Calculate angles for the remaining connections
      angle.clear();
      next.clear();
      for (int i = 0; i < connected.size(); i++) {
        Vertex otherEnd = isA.get(i) ? connected.get(i).bConnected : connected.get(i).aConnected;
        next.add(otherEnd);
        angle.add(atan2(otherEnd.pos.y - pos.y, otherEnd.pos.x - pos.x));
      }

      // Sort the lists by angle
      for (int i = 0; i < angle.size() - 1; i++) {
        for (int j = i + 1; j < angle.size(); j++) {
          if (angle.get(i) > angle.get(j)) {
            // Swap angles
            float tempAngle = angle.get(i);
            angle.set(i, angle.get(j));
            angle.set(j, tempAngle);

            // Swap connected segments
            SegmentProcessor.Segment tempSegment = connected.get(i);
            connected.set(i, connected.get(j));
            connected.set(j, tempSegment);

            // Swap isA values
            Boolean tempIsA = isA.get(i);
            isA.set(i, isA.get(j));
            isA.set(j, tempIsA);

            // Swap next values
            Vertex tempNext = next.get(i);
            next.set(i, next.get(j));
            next.set(j, tempNext);
          }
        }
      }
    }
  }
}
