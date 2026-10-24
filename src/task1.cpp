#include "yaml-cpp/yaml.h"
#include <iostream>
#include <yaml-cpp/node/node.h>
#include <yaml-cpp/node/parse.h>
#include <yaml-cpp/yaml.h>
#include <optional>
#include <filesystem>
#include <thread>

using namespace std::chrono_literals;

// 读取数值函数
template<class T>
std::optional<T> readValue(const YAML::Node& node, const std::string& key) {
    // key是否存在
    if (!node[key].IsDefined()) {
        std::cerr << key + "不存在\n";
        return std::nullopt;
    }

    // key是否有值
    if (node[key].IsNull()) {
        std::cerr << "KEY " + key + " 不存在对应VALUE\n";
        return std::nullopt;
    }

    // 取值
    return node[key].as<T>();
}

int main()
{
    YAML::Node node;
    int a;
    int b;
    std::string configPath = "/home/yq/my_project/cpp/27赛季算法作业/27赛季算法作业/ws_exam_2/config/config.yaml";
    // 读取
    try {
        node = YAML::LoadFile(configPath);
    } catch (const YAML::Exception& e) {
        std::cerr << "YAML 文件不存在: " << e.what() << "\n";
        return -1;
    }
    // 取值
    try {
        auto aa = readValue<int>(node, "a");
        auto bb = readValue<int>(node, "b");

        if (!aa.has_value() || !bb.has_value()) {
            return -1;
        }

        a = aa.value();
        b = bb.value();
    } catch (const YAML::Exception& e) { // 接类型转换错误
        std::cerr << "VALUE 类型转换失败: " << e.what() << "\n";
        return -1;
    }

    std::cout << "a = " << a << "\n"
    << "b = " << b << "\n"
    << "a + b = " << a + b << "\n";

    auto lastModifiedTime = std::filesystem::last_write_time(configPath);

    while (true) {
        std::this_thread::sleep_for(500ms); // 0.5s检测一次
        auto currModifiedTime = std::filesystem::last_write_time(configPath);
        if (lastModifiedTime != currModifiedTime) {
            // 状态更新
            lastModifiedTime = currModifiedTime;
            std::cout << "====== 检测到 YAML 被修改 ======\n";
            // 读取
            try {
                node = YAML::LoadFile(configPath);
            } catch (const YAML::Exception& e) {
                std::cerr << "YAML 文件不存在: " << e.what() << "\n";
                return -1;
            }

            // 取值
            try {
                auto aa = readValue<int>(node, "a");
                auto bb = readValue<int>(node, "b");

                if (!aa.has_value() || !bb.has_value()) {
                    return -1;
                }

                a = aa.value();
                b = bb.value();
            } catch (const YAML::Exception& e) { // 接类型转换错误
                std::cerr << "VALUE 类型转换失败: " << e.what() << "\n";
                return -1;
            }

            std::cout << "a = " << a << "\n"
            << "b = " << b << "\n"
            << "a + b = " << a + b << "\n";
        }
    }

    return 0;
}