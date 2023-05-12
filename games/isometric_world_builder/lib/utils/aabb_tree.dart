import 'dart:collection';
import 'dart:math';

import 'package:rive_common/math.dart';

// Inspired from Box2D Dynamic Tree:
// https://github.com/behdad/box2d/blob/master/Box2D/Box2D/Collision/b2DynamicTree.h

const int nullNode = -1;
// const int AABBExtension = 10;
const double _multiplier = 2.0;

typedef QueryCallback<T> = bool Function(int id, T userData);
typedef RayCallback<T> = double Function(RaySegment ray, int id, T userData);

class RaySegment {
  final Vec2D start;
  final Vec2D end;
  final double fraction;

  RaySegment(this.start, this.end) : fraction = 1;
  RaySegment._(this.start, this.end, this.fraction);
}

class TreeNode<T> {
  int next = 0;
  int child1 = nullNode;
  int child2 = nullNode;
  final AABB _aabb = AABB();
  int height = -1;
  T? userData;

  TreeNode();

  AABB get aabb {
    return _aabb;
  }

  bool get isLeaf {
    return child1 == nullNode;
  }

  int get parent {
    return next;
  }

  set parent(int n) {
    next = n;
  }
}

class AABBTree<T> {
  int _root = nullNode;
  int _capacity = 0;
  int _nodeCount = 0;
  final List<TreeNode<T>> _nodes = [];
  int _freeNode = 0;

  AABBTree() {
    _allocateNodes();
  }

  void clear() {
    _root = nullNode;
    _capacity = 0;
    _nodeCount = 0;
    _nodes.clear();
    _freeNode = 0;
    _allocateNodes();
  }

  void _allocateNodes() {
    _freeNode = _nodeCount;

    if (_capacity == 0) {
      _capacity = 16;
    } else {
      _capacity *= 2;
    }
    int count = _capacity;
    for (int i = _nodeCount; i < count; i++) {
      TreeNode<T> node = TreeNode<T>();
      node.next = _nodes.length + 1;
      _nodes.add(node);
    }
    _nodes[_nodes.length - 1].next = nullNode;
  }

  int _allocateNode() {
    if (_freeNode == nullNode) {
      _allocateNodes();
    }

    int nodeId = _freeNode;
    TreeNode<T> node = _nodes[nodeId];
    _freeNode = node.next;
    node.parent = nullNode;
    node.child1 = nullNode;
    node.child2 = nullNode;
    node.height = 0;
    node.userData = null;
    _nodeCount++;
    return nodeId;
  }

  void _disposeNode(int nodeId) {
    if (nodeId < 0 || nodeId >= _capacity) {
      throw RangeError.range(nodeId, 0, _capacity, 'NodeID', 'Out of bounds!');
    }
    if (_nodeCount <= 0) {
      throw StateError('Node count is not valid');
    }

    TreeNode<T> node = _nodes[nodeId];
    node.next = _freeNode;
    node.userData = null;
    node.height = -1;
    _freeNode = nodeId;
    _nodeCount--;
  }

  int createProxy(AABB aabb, T userData, {double padding = 10}) {
    int proxyId = _allocateNode();
    TreeNode<T> node = _nodes[proxyId];
    node.aabb[0] = aabb[0] - padding;
    node.aabb[1] = aabb[1] - padding;
    node.aabb[2] = aabb[2] + padding;
    node.aabb[3] = aabb[3] + padding;
    node.userData = userData;
    node.height = 0;

    insertLeaf(proxyId);

    return proxyId;
  }

  void destroyProxy(int proxyId) {
    if (proxyId < 0 || proxyId >= _capacity) {
      throw RangeError.range(
          proxyId, 0, _capacity, 'proxyId', 'Out of bounds!');
    }

    TreeNode<T> node = _nodes[proxyId];
    if (!node.isLeaf) {
      throw StateError('Node is not a leaf!');
    }

    removeLeaf(proxyId);
    _disposeNode(proxyId);
  }

  bool placeProxy(int proxyId, AABB aabb, {double padding = 10}) {
    if (proxyId < 0 || proxyId >= _capacity) {
      throw RangeError.range(
          proxyId, 0, _capacity, 'proxyId', 'Out of bounds!');
    }

    TreeNode<T> node = _nodes[proxyId];
    if (!node.isLeaf) {
      throw StateError('Node is not a leaf!');
    }

    if (node.aabb.containsBounds(aabb)) {
      return false;
    }

    removeLeaf(proxyId);

    AABB extended = AABB.clone(aabb);
    extended[0] = aabb[0] - padding;
    extended[1] = aabb[1] - padding;
    extended[2] = aabb[2] + padding;
    extended[3] = aabb[3] + padding;
    AABB.copy(node.aabb, extended);

    insertLeaf(proxyId);
    return true;
  }

  bool moveProxy(int proxyId, AABB aabb, AABB displacement,
      {double padding = 10}) {
    if (proxyId < 0 || proxyId >= _capacity) {
      throw RangeError.range(
          proxyId, 0, _capacity, 'proxyId', 'Out of bounds!');
    }

    TreeNode<T> node = _nodes[proxyId];
    if (!node.isLeaf) {
      throw StateError('Node is not a leaf!');
    }

    if (node.aabb.containsBounds(aabb)) {
      return false;
    }

    removeLeaf(proxyId);

    AABB extended = AABB.clone(aabb);
    extended[0] = aabb[0] - padding;
    extended[1] = aabb[1] - padding;
    extended[2] = aabb[2] + padding;
    extended[3] = aabb[3] + padding;

    double dx = _multiplier * displacement[0];
    double dy = _multiplier * displacement[1];

    if (dx < 0.0) {
      extended[0] += dx;
    } else {
      extended[2] += dx;
    }

    if (dy < 0.0) {
      extended[1] += dy;
    } else {
      extended[3] += dy;
    }

    AABB.copy(node.aabb, extended);

    insertLeaf(proxyId);
    return true;
  }

  void insertLeaf(int leaf) {
    if (_root == nullNode) {
      _root = leaf;
      _nodes[_root].parent = nullNode;
      return;
    }

    // Find the best sibling for this node
    AABB leafAABB = _nodes[leaf].aabb;
    int index = _root;

    while (_nodes[index].isLeaf == false) {
      var node = _nodes[index];
      int child1 = node.child1;
      int child2 = node.child2;

      double area = AABB.perimeter(node.aabb);

      AABB combinedAABB = AABB.combine(AABB(), node.aabb, leafAABB);
      double combinedArea = AABB.perimeter(combinedAABB);

      // Cost of creating a parent for this node and the leaf
      double cost = 2.0 * combinedArea;

      // Min cost of pushing the leaf further down the tree
      double inheritanceCost = 2.0 * (combinedArea - area);

      // Cost of descending into child1
      double cost1;
      if (_nodes[child1].isLeaf) {
        AABB aabb = AABB.combine(AABB(), leafAABB, _nodes[child1].aabb);
        cost1 = AABB.perimeter(aabb) + inheritanceCost;
      } else {
        AABB aabb = AABB.combine(AABB(), leafAABB, _nodes[child1].aabb);
        double oldArea = AABB.perimeter(_nodes[child1].aabb);
        double newArea = AABB.perimeter(aabb);
        cost1 = (newArea - oldArea) + inheritanceCost;
      }

      double cost2;
      if (_nodes[child2].isLeaf) {
        AABB aabb = AABB.combine(AABB(), leafAABB, _nodes[child2].aabb);
        cost2 = AABB.perimeter(aabb) + inheritanceCost;
      } else {
        AABB aabb = AABB.combine(AABB(), leafAABB, _nodes[child2].aabb);
        double oldArea = AABB.perimeter(_nodes[child2].aabb);
        double newArea = AABB.perimeter(aabb);
        cost2 = (newArea - oldArea) + inheritanceCost;
      }

      // Descend according to the min cost
      if (cost < cost1 && cost < cost2) {
        break;
      }

      // Descend
      if (cost1 < cost2) {
        index = child1;
      } else {
        index = child2;
      }
    }

    int sibling = index;

    // Create parent
    int oldParent = _nodes[sibling].parent;
    int newParent = _allocateNode();
    _nodes[newParent].parent = oldParent;
    _nodes[newParent].userData = null;
    AABB.combine(_nodes[newParent].aabb, leafAABB, _nodes[sibling].aabb);
    _nodes[newParent].height = _nodes[sibling].height + 1;

    if (oldParent != nullNode) {
      // The sibling was not the root
      if (_nodes[oldParent].child1 == sibling) {
        _nodes[oldParent].child1 = newParent;
      } else {
        _nodes[oldParent].child2 = newParent;
      }

      _nodes[newParent].child1 = sibling;
      _nodes[newParent].child2 = leaf;
      _nodes[sibling].parent = newParent;
      _nodes[leaf].parent = newParent;
    } else {
      // The sibling was the root
      _nodes[newParent].child1 = sibling;
      _nodes[newParent].child2 = leaf;
      _nodes[sibling].parent = newParent;
      _nodes[leaf].parent = newParent;
      _root = newParent;
    }

    // Walk back up the tree fixing heights and AABBs
    index = _nodes[leaf].parent;
    while (index != nullNode) {
      index = _balance(index);

      var node = _nodes[index];

      int child1 = node.child1;
      int child2 = node.child2;

      if (child1 == nullNode) {
        throw StateError('Child1 is NULL!');
      }
      if (child2 == nullNode) {
        throw StateError('Child2 is NULL!');
      }

      node.height =
          1 + max(_nodes[child1].height, _nodes[child2].height).toInt();
      AABB.combine(node.aabb, _nodes[child1].aabb, _nodes[child2].aabb);

      index = node.parent;
    }
  }

  void removeLeaf(int leaf) {
    if (leaf == _root) {
      _root = nullNode;
      return;
    }

    int parent = _nodes[leaf].parent;
    int grandParent = _nodes[parent].parent;
    int sibling;

    if (_nodes[parent].child1 == leaf) {
      sibling = _nodes[parent].child2;
    } else {
      sibling = _nodes[parent].child1;
    }

    if (grandParent != nullNode) {
      // Destroy parent and connect sibling to grandParent
      if (_nodes[grandParent].child1 == parent) {
        _nodes[grandParent].child1 = sibling;
      } else {
        _nodes[grandParent].child2 = sibling;
      }

      _nodes[sibling].parent = grandParent;
      _disposeNode(parent);

      // Adjust ancestor bounds

      int index = grandParent;
      while (index != nullNode) {
        index = _balance(index);

        int child1 = _nodes[index].child1;
        int child2 = _nodes[index].child2;

        AABB.combine(
            _nodes[index].aabb, _nodes[child1].aabb, _nodes[child2].aabb);
        _nodes[index].height =
            1 + max(_nodes[child1].height, _nodes[child2].height).toInt();

        index = _nodes[index].parent;
      }
    } else {
      _root = sibling;
      _nodes[sibling].parent = nullNode;
      _disposeNode(parent);
    }
  }

  // Perform a left or right rotation if node A is imbalanced
  // Returns the root index
  int _balance(int iA) {
    if (iA == nullNode) {
      throw StateError('iA should not be Null!');
    }

    TreeNode<T> A = _nodes[iA];
    if (A.isLeaf || A.height < 2) {
      return iA;
    }

    int iB = A.child1;
    int iC = A.child2;

    if (iB < 0 || iB >= _capacity) {
      throw RangeError.range(iB, 0, _capacity, 'iB', 'Out of bounds!');
    }
    if (iC < 0 || iC >= _capacity) {
      throw RangeError.range(iC, 0, _capacity, 'iC', 'Out of bounds!');
    }

    TreeNode<T> B = _nodes[iB];
    TreeNode<T> C = _nodes[iC];

    int balance = C.height - B.height;

    // Rotate C up
    if (balance > 1) {
      int iF = C.child1;
      int iG = C.child2;
      TreeNode<T> F = _nodes[iF];
      TreeNode<T> G = _nodes[iG];

      if (iF < 0 || iF >= _capacity) {
        throw RangeError.range(iF, 0, _capacity, 'iF', 'Out of bounds!');
      }
      if (iG < 0 || iG >= _capacity) {
        throw RangeError.range(iG, 0, _capacity, 'iG', 'Out of bounds!');
      }

      // Swap A and C
      C.child1 = iA;
      C.parent = A.parent;
      A.parent = iC;

      // A's old parent should point to C
      if (C.parent != nullNode) {
        if (_nodes[C.parent].child1 == iA) {
          _nodes[C.parent].child1 = iC;
        } else {
          if (_nodes[C.parent].child2 != iA) {
            throw StateError('Bad child2');
          }
          _nodes[C.parent].child2 = iC;
        }
      } else {
        _root = iC;
      }

      // Rotate
      if (F.height > G.height) {
        C.child2 = iF;
        A.child2 = iG;
        G.parent = iA;
        AABB.combine(A.aabb, B.aabb, G.aabb);
        AABB.combine(C.aabb, A.aabb, F.aabb);

        A.height = 1 + max(B.height, G.height).toInt();
        C.height = 1 + max(A.height, F.height).toInt();
      } else {
        C.child2 = iG;
        A.child2 = iF;
        F.parent = iA;
        AABB.combine(A.aabb, B.aabb, F.aabb);
        AABB.combine(C.aabb, A.aabb, G.aabb);

        A.height = 1 + max(B.height, F.height).toInt();
        C.height = 1 + max(A.height, G.height).toInt();
      }

      return iC;
    }

    // Rotate B up
    if (balance < -1) {
      int iD = B.child1;
      int iE = B.child2;
      TreeNode<T> D = _nodes[iD];
      TreeNode<T> E = _nodes[iE];

      if (iD < 0 || iD >= _capacity) {
        throw RangeError.range(iD, 0, _capacity, 'iD', 'Out of bounds!');
      }
      if (iE < 0 || iE >= _capacity) {
        throw RangeError.range(iE, 0, _capacity, 'iE', 'Out of bounds!');
      }

      // Swap A and B
      B.child1 = iA;
      B.parent = A.parent;
      A.parent = iB;

      // A's old parent should point to B
      if (B.parent != nullNode) {
        if (_nodes[B.parent].child1 == iA) {
          _nodes[B.parent].child1 = iB;
        } else {
          if (_nodes[B.parent].child2 != iA) {
            throw StateError('Bad child2, expected equal iA: $iA');
          }
          _nodes[B.parent].child2 = iB;
        }
      } else {
        _root = iB;
      }

      // Rotate
      if (D.height > E.height) {
        B.child2 = iD;
        A.child1 = iE;
        E.parent = iA;
        AABB.combine(A.aabb, C.aabb, E.aabb);
        AABB.combine(B.aabb, A.aabb, D.aabb);

        A.height = 1 + max(C.height, E.height).toInt();
        B.height = 1 + max(A.height, D.height).toInt();
      } else {
        B.child2 = iE;
        A.child1 = iD;
        D.parent = iA;
        AABB.combine(A.aabb, C.aabb, D.aabb);
        AABB.combine(B.aabb, A.aabb, E.aabb);

        A.height = 1 + max(C.height, D.height).toInt();
        B.height = 1 + max(A.height, E.height).toInt();
      }

      return iB;
    }

    return iA;
  }

  int getHeight() {
    if (_root == nullNode) {
      return 0;
    }

    return _nodes[_root].height;
  }

  double getAreaRatio() {
    if (_root == nullNode) {
      return 0.0;
    }

    TreeNode<T> root = _nodes[_root];
    double rootArea = AABB.perimeter(root.aabb);

    double totalArea = 0.0;
    int capacity = _capacity;
    for (int i = 0; i < capacity; i++) {
      TreeNode<T> node = _nodes[i];
      if (node.height < 0) {
        continue;
      }

      totalArea += AABB.perimeter(node.aabb);
    }

    return totalArea / rootArea;
  }

  // Compute the height of a subtree
  int computeHeight(int nodeId) {
    // nodeId ??= _root;

    if (nodeId < 0 || nodeId >= _capacity) {
      throw RangeError.range(nodeId, 0, _capacity, 'nodeId', 'Out of bounds!');
    }
    var node = _nodes[nodeId];

    if (node.isLeaf) {
      return 0;
    }

    int height1 = computeHeight(node.child1);
    int height2 = computeHeight(node.child2);
    return 1 + max(height1, height2).toInt();
  }

  void validateStructure(int index) {
    if (index == nullNode) {
      return;
    }

    List<TreeNode> nodes = _nodes;
    if (index == _root) {
      if (nodes[index].parent != nullNode) {
        throw StateError('Expected parent to be null!');
      }
    }

    var node = nodes[index];
    int child1 = node.child1;
    int child2 = node.child2;

    if (node.isLeaf) {
      if (child1 != nullNode) {
        throw StateError('Expected child1 to be null!');
      }
      if (child2 != nullNode) {
        throw StateError('Expected child2 to be null!');
      }
      if (node.height != 0) {
        throw StateError('Expected node\'s height to be 0!');
      }
      return;
    }

    if (child1 < 0 || child1 >= _capacity) {
      throw RangeError.range(child1, 0, _capacity, 'child1', 'Out of bounds!');
    }
    if (child2 < 0 || child2 >= _capacity) {
      throw RangeError.range(child2, 0, _capacity, 'child2', 'Out of bounds!');
    }

    if (nodes[child1].parent != index) {
      throw StateError('Expected child1 parent to be $index');
    }
    if (nodes[child2].parent != index) {
      throw StateError('Expected child2 parent to be $index');
    }

    validateStructure(child1);
    validateStructure(child2);
  }

  void validateMetrics(int index) {
    if (index == nullNode) {
      return;
    }

    var node = _nodes[index];

    int child1 = node.child1;
    int child2 = node.child2;

    if (node.isLeaf) {
      if (child1 != nullNode) {
        throw StateError('Expected child1 to be null!');
      }
      if (child2 != nullNode) {
        throw StateError('Expected child2 to be null!');
      }
      if (node.height != 0) {
        throw StateError('Expected node\'s height to be 0!');
      }
      return;
    }

    if (child1 < 0 || child1 >= _capacity) {
      throw RangeError.range(child1, 0, _capacity, 'child1', 'Out of bounds!');
    }
    if (child2 < 0 || child2 >= _capacity) {
      throw RangeError.range(child2, 0, _capacity, 'child2', 'Out of bounds!');
    }

    int height1 = _nodes[child1].height;
    int height2 = _nodes[child2].height;
    int height;
    height = 1 + max(height1, height2).toInt();

    if (node.height != height) {
      throw StateError('Expected node\'s height to be $height');
    }

    AABB aabb = AABB.combine(AABB(), _nodes[child1].aabb, _nodes[child2].aabb);

    if (aabb[0] != node.aabb[0] || aabb[1] != node.aabb[1]) {
      throw StateError('Lower Bound is not equal!');
    }
    if (aabb[2] != node.aabb[2] || aabb[3] != node.aabb[3]) {
      throw StateError('Upper Bound is not equal!');
    }

    validateMetrics(child1);
    validateMetrics(child2);
  }

  void validate() {
    validateStructure(_root);
    validateMetrics(_root);

    int freeCount = 0;
    int freeIndex = _freeNode;
    while (freeIndex != nullNode) {
      if (freeIndex < 0 || freeIndex >= _capacity) {
        throw RangeError.range(
            freeIndex, 0, _capacity, 'freeIndex', 'Out of bounds!');
      }
      freeIndex = _nodes[freeIndex].next;
      ++freeCount;
    }

    if (getHeight() != computeHeight(_root)) {
      throw StateError('Expected height to match computed height.');
    }

    if (_nodeCount + freeCount != _capacity) {
      throw AssertionError(
          'Expected node count + free count to equal capactiy!');
    }
  }

  int getMaxBalance() {
    int maxBalance = 0;
    int capacity = _capacity;
    for (int i = 0; i < capacity; i++) {
      var node = _nodes[i];
      if (node.height < 1) {
        continue;
      }

      if (node.isLeaf) {
        throw StateError('Expected node not to be a leaf!');
      }

      int child1 = node.child1;
      int child2 = node.child2;
      int balance = (_nodes[child2].height - _nodes[child1].height).abs();
      maxBalance = max(maxBalance, balance);
    }

    return maxBalance;
  }

  T? getUserdata(int proxyId) {
    return _nodes[proxyId].userData;
  }

  AABB getFatAABB(int proxyId) {
    return _nodes[proxyId].aabb;
  }

  /// Get a linear list representng the current state of the tree. This makes a
  /// new list so the tree is safe to modify while iterating the returned value.
  List<T> toList() {
    var items = <T>[];
    all((_, item) {
      if (item != null) {
        items.add(item);
      }

      return true;
    });
    return items;
  }

  void all(QueryCallback<T> callback) {
    var stack = ListQueue<int>();
    stack.addLast(_root);

    while (stack.isNotEmpty) {
      int nodeId = stack.removeLast();
      if (nodeId == nullNode) {
        continue;
      }

      var node = _nodes[nodeId];

      if (node.isLeaf) {
        if (node.userData != null) {
          bool proceed = callback(nodeId, node.userData as T);
          if (!proceed) {
            return;
          }
        }
      } else {
        stack.addLast(node.child1);
        stack.addLast(node.child2);
      }
    }
  }

  Iterable<K> whereType<K>() {
    List<K> items = [];
    all((_, item) {
      if (item is K) {
        items.add(item);
      }
      return true;
    });

    return items;
  }

  void query(AABB aabb, QueryCallback<T> callback) {
    var stack = ListQueue<int>();
    stack.addLast(_root);

    while (stack.isNotEmpty) {
      int nodeId = stack.removeLast();
      if (nodeId == nullNode) {
        continue;
      }

      TreeNode<T> node = _nodes[nodeId];

      if (AABB.testOverlap(node.aabb, aabb)) {
        if (node.isLeaf) {
          if (node.userData != null) {
            bool proceed = callback(nodeId, node.userData as T);
            if (proceed == false) {
              return;
            }
          }
        } else {
          stack.addLast(node.child1);
          stack.addLast(node.child2);
        }
      }
    }
  }

  double raycast(RaySegment ray, RayCallback<T> callback) {
    var p1 = ray.start;
    var p2 = ray.end;
    var r = p2 - p1;
    r.norm();
    var v = Vec2D.fromValues(-1 * r.y, 1 * r.x);
    var absV = Vec2D.fromValues(v.x.abs(), v.y.abs());
    // b2Vec2 abs_v = b2Abs(v);

    // Separating axis for segment (Gino, p80).
    // |dot(v, p1 - c)| > dot(|v|, h)

    var fraction = ray.fraction;

    // Build a bounding box for the segment.
    var t = p1 + (p2 - p1) * fraction;
    var segmentAABB = AABB.fromMinMax(
        Vec2D.fromValues(min(p1.x, t.x), min(p1.y, t.y)),
        Vec2D.fromValues(max(p1.x, t.x), max(p1.y, t.y)));

    var stack = ListQueue<int>();
    stack.addLast(_root);

    while (stack.isNotEmpty) {
      int nodeId = stack.removeLast();
      if (nodeId == nullNode) {
        continue;
      }

      TreeNode<T> node = _nodes[nodeId];

      if (!AABB.testOverlap(node.aabb, segmentAABB)) {
        continue;
      }

      // Separating axis for segment (Gino, p80).
      // |dot(v, p1 - c)| > dot(|v|, h)
      var c = node.aabb.center();
      var h = AABB.extents(Vec2D(), node.aabb);
      double separation = Vec2D.dot(v, p1 - c).abs() - Vec2D.dot(absV, h);
      if (separation > 0) {
        continue;
      }

      if (node.isLeaf) {
        if (node.userData == null) {
          continue;
        }
        var subInput = RaySegment._(ray.start, ray.end, fraction);

        var value = callback(subInput, nodeId, node.userData as T);

        if (value == 0) {
          // The client has terminated the ray cast.
          return fraction;
        }

        if (value > 0) {
          // Update segment bounding box.
          fraction = value;
          t = p1 + (p2 - p1) * fraction;
          segmentAABB = AABB.fromMinMax(
              Vec2D.fromValues(min(p1.x, t.x), min(p1.y, t.y)),
              Vec2D.fromValues(max(p1.x, t.x), max(p1.y, t.y)));
        }
      } else {
        stack.addLast(node.child1);
        stack.addLast(node.child2);
      }
    }
    return fraction;
  }
}
