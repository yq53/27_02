## task 1

### 参考教程

- [yaml-cpp源码](https://github.com/jbeder/yaml-cpp)
- [基础要求](https://txtmix.com/posts/tech/jbeder-yaml-cpp-cpp-yaml-parser-complete-guide/)

### 有关热更新

实际是一开始的思路是维护两个config变量，一个表示currConfig，一个是lastConfig，通过while循环 + 一个timer定时读取，并比较变化。后面和chatgpt讨论提醒后，想起来还有个`std::filesystem::last_write_time(path)`函数，所以就换成直接检测文件修改时间，并比较时间了，这比每次都读取一次省事多了

---

## task2

其实只要知道终端启动会自动执行一遍.bashrc就行了，挺简单的，所以我决定让gpt写了个小动画。

- [原脚本](../src/task2raw.sh)
- [动画](../src/task2.sh)
- [演示](../src/task2.mkv)
- [参考视频](https://www.bilibili.com/video/BV1Gx4y1V747)

---

## task4

其实算复习了，做的过程就是翻几个月前学的时候写的几个demo，然后开始缝合

### 参考教程

- [我自己](https://github.com/yq53/demo)

---

## 学习进度

学了学yolo模型的训练以及使用tensorrt在nvidia gpu上完成模型部署以及推理输出。

- [tensorrt demo](https://github.com/yq53/tensorrt_cpp_demo)