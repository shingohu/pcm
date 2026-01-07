import 'dart:async';

class SimpleLock {
  // 标记当前锁是否被占用
  bool _locked = false;

  // 等待获取锁的任务队列（存储 Completer 用于唤醒等待的任务）
  final List<Completer<void>> _waitingQueue = [];

  /// 获取锁（阻塞直到获取到锁）
  Future<void> lock() async {
    // 如果锁未被占用，直接获取锁
    if (!_locked) {
      _locked = true;
      return;
    }

    // 如果锁已被占用，创建 Completer 并加入等待队列，等待被唤醒
    final completer = Completer<void>();
    _waitingQueue.add(completer);
    await completer.future;
  }

  /// 释放锁（唤醒等待队列中的下一个任务）
  void unlock() {
    // 如果没有等待的任务，直接释放锁
    if (_waitingQueue.isEmpty) {
      _locked = false;
      return;
    }

    // 唤醒等待队列中的第一个任务
    final nextCompleter = _waitingQueue.removeAt(0);
    nextCompleter.complete();
  }

  /// 同步执行代码块（核心方法，自动加锁/解锁）
  Future<T> synchronized<T>(FutureOr<T> Function() callback) async {
    // 1. 获取锁（阻塞直到拿到锁）
    await lock();
    try {
      // 2. 执行临界区代码
      return await callback();
    } finally {
      // 3. 无论代码执行成功/失败，都要释放锁（避免死锁）
      unlock();
    }
  }
}
