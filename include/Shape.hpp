#include <array>
#include <cmath>
#include <iostream>
#include <numbers>


namespace myShape {
    class Shape
    {
    public:
        // 计算面积
        virtual double area() const = 0;

        // 计算周长
        virtual double perimeter() const = 0;

        virtual ~Shape() = default;
    };

    // 三角形
    class Triangle : public Shape
    {
    public:
        // 初始化
        Triangle(double a, double b, double c) {
            // 保证可形成三角形
            if (a + b > c && b + c > a && a + c > b) {
                this->a_ = a;
                this->b_ = b;
                this->c_ = c;
            }
            else {
                std::cerr << "三条边无法形成三角形\n";
                return;
            }
        };

        // 面积
        double area() const override {
            double p = (a_ + b_ + c_) / 2.0;
            return std::sqrt(p * (p - a_) * (p - b_) * (p - c_));
        }

        // 周长
        double perimeter() const override {
            return a_ + b_ + c_;
        }

        // 输出函数
        void printInfo() const {
            std::cout << "三角形(边长 " << a_ << "、" << b_ << c_ << "): "
                    << "面积 = " << this->area() << ", "
                    << "周长 = " << this->perimeter() << "\n";
        }

        ~Triangle() = default;

    private:
        // 三条边
        int a_, b_, c_;
    };

    // 矩形
    class Rectengle : public Shape
    {
    public:
        Rectengle(double length, double width) : length_(length), width_(width) {};

        // 面积
        double area() const override {
            return length_ * width_;
        }

        // 周长
        double perimeter() const override {
            return 2 * length_ + 2 * width_;
        }

        // 打印
            // 输出函数
        void printInfo() const {
            std::cout << "矩形(长 " << length_ << "宽 " << width_ << "): "
                    << "面积 = " << this->area() << ", "
                    << "周长 = " << this->perimeter() << "\n";
        }

    private:
        // 边长
        double length_;
        double width_;
    };

    // 圆形
    class Circle : public Shape
    {
    public:
        Circle(double r) : r_(r) {};

        double area() const override {
            return std::numbers::pi * r_ * r_;
        }

        double perimeter() const override {
            return 2 * std::numbers::pi * r_;
        }

        void printInfo() const {
            std::cout << "圆形(半径 " << r_  << "): "
                    << "面积 = " << this->area() << ", "
                    << "周长 = " << this->perimeter() << "\n";
        }

    private:
        double r_;
    };
}
