/*
 * 环形缓冲区（线程安全，单生产者-单消费者）
 *
 * 用于累积 AudioCapturer 回调的 PCM 数据，凑够分析窗口后供音高检测
 */

#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <cstdint>
#include <cstring>
#include <vector>

class RingBuffer {
public:
    explicit RingBuffer(size_t capacity) : capacity_(capacity), data_(capacity, 0) {}

    // 写入数据，返回实际写入样本数
    size_t write(const int16_t* src, size_t count) {
        if (count == 0) {
            return 0;
        }
        // 若写入超过容量，只保留最后 capacity 个样本（丢弃最旧的）
        size_t toWrite = count > capacity_ ? capacity_ : count;
        const int16_t* srcAdjusted = (count > capacity_) ? (src + (count - capacity_)) : src;
        for (size_t i = 0; i < toWrite; ++i) {
            data_[(writePos_ + i) % capacity_] = srcAdjusted[i];
        }
        writePos_ = (writePos_ + toWrite) % capacity_;
        size_ += toWrite;
        if (size_ > capacity_) {
            size_ = capacity_;
            // 写指针绕回后，读指针也随之推进
            readPos_ = (writePos_ + capacity_ - size_) % capacity_;
        }
        return toWrite;
    }

    // 读取最多 count 个样本（FIFO），返回实际读取数
    size_t read(int16_t* dst, size_t count) {
        size_t toRead = count > size_ ? size_ : count;
        for (size_t i = 0; i < toRead; ++i) {
            dst[i] = data_[(readPos_ + i) % capacity_];
        }
        readPos_ = (readPos_ + toRead) % capacity_;
        size_ -= toRead;
        return toRead;
    }

    // 拷贝最近 count 个样本（不消费，用于读取完整窗口）
    size_t peekLatest(int16_t* dst, size_t count) const {
        size_t toRead = count > size_ ? size_ : count;
        // 从写指针向前回退 toRead，确保取到最新窗口；原实现缓冲积满后会误取最旧数据。
        size_t start = (writePos_ + capacity_ - toRead) % capacity_;
        for (size_t i = 0; i < toRead; ++i) {
            dst[i] = data_[(start + i) % capacity_];
        }
        return toRead;
    }

    // 当前可读样本数
    size_t size() const { return size_; }

    // 清空
    void clear() {
        size_ = 0;
        readPos_ = 0;
        writePos_ = 0;
    }

private:
    size_t capacity_;
    size_t size_ = 0;
    size_t readPos_ = 0;
    size_t writePos_ = 0;
    std::vector<int16_t> data_;
};

#endif // RING_BUFFER_H
