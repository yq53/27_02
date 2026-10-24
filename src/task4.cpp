#include <algorithm>
#include <cstdint>
#include <iostream>
#include <ratio>
#include <thread>
#include <chrono>
#include <vector>
#include <mutex>
#include <deque>
#include <condition_variable>
#include <random>
#include <utility>

using namespace std::chrono_literals;

struct SensorPacket {
    std::uint64_t id;
    std::chrono::steady_clock::time_point send_time;
    std::vector<int> values;
};

// 线程安全队列
template<class T>
class mt_queue
{
public:
    // 推入数据，成功则返回 true
    bool push(T value)
    {
        { // lock
            std::unique_lock<std::mutex> lock(m_mutex);

            // 队列关闭，不接收新数据
            if (m_closed) {
                return false;
            }

            // 生产者推送数据
            m_queue.push_back(std::move(value));
        } // unlock
        
        // 通知某一个消费者
        m_cv.notify_one();
        return true;
    }

    // 等待并取出数据
    bool pop(T& value)
    {
        std::unique_lock<std::mutex> lock(m_mutex);

        // 等待队列中有数据 或 队列关闭
        m_cv.wait(lock, [this] {
            return m_closed || !m_queue.empty();
        });

        // 所有数据都处理完了
        if (m_queue.empty()) {
            return false;
        }

        // 消费者取数据
        value = std::move(m_queue.front());
        m_queue.pop_front();
        
        return true;
    }

    // 队列关闭
    void close()
    {
        { // lock
            std::lock_guard<std::mutex> lock(m_mutex);
            m_closed = true;
        } // unlock

        // 通知所有消费者
        m_cv.notify_all();
    }

private:
    std::deque<T> m_queue;
    std::mutex m_mutex;
    std::condition_variable m_cv;
    bool m_closed = false;
};

mt_queue<SensorPacket> sensorDataQueue;  // 共享队列

// 发送数据
void sendData() {
    // 随机数生成器
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<int> dist(0, 100);

    // 发20个数据
    for (int i = 0; i < 20; i++) {
        // 初始化一个数据
        SensorPacket sensorData;

        // 组织数据
        sensorData.id = i;
        for (int j = 0; j < 5; j++) {
            sensorData.values.push_back(dist(gen));
        }

        // 发送
        sensorData.send_time = std::chrono::steady_clock::now();
        if (!sensorDataQueue.push(std::move(sensorData))) {
            std::cerr << "[错误] id=" << sensorData.id  << ", 数据发送失败!\n";
            return;
        }

        // 间隔100ms
        if (i < 19) {
            std::this_thread::sleep_for(100ms);
        }
    }

    // 发送完毕，关闭队列
    sensorDataQueue.close();
}

// 接收并处理数据
void processData() {
    // 初始化接收
    SensorPacket sensorData;

    // 获取数据
    while (sensorDataQueue.pop(sensorData)) {
        // 处理
        int minValue = *std::min_element(sensorData.values.begin(), sensorData.values.end());
        int maxValue = *std::max_element(sensorData.values.begin(), sensorData.values.end());
        double meanValue = 0;
        for (auto& value : sensorData.values) {
            meanValue += value;
        }
        meanValue /= static_cast<double>(sensorData.values.size());
        // 转换为ms
        auto timeCost = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - sensorData.send_time);

        // 输出
        std::cout << "[结果] id=" << sensorData.id << ", [";
        for (int i = 0; i < static_cast<int>(sensorData.values.size()); i++) {
            if (i > 0) {
                std::cout << ", ";
            }

            std::cout << sensorData.values[i];
        }
        std::cout << "]" 
                << ", 最小值=" << minValue 
                << ", 最大值=" << maxValue
                << ", 平均值=" << meanValue
                << ", 耗时=" << timeCost.count() << " ms\n";
    }
}

int main()
{
    std::cout << "小洁的传感器监测程序已启动\n";

    std::jthread producer(sendData);
    std::jthread consumer(processData);

    producer.join();
    consumer.join();

    std::cout << "采集与处理完成，共处理 20 组数据，程序退出\n";

    return 0;
}