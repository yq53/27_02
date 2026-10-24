#include "Shape.hpp"

int main()
{
    myShape::Triangle t(3, 4, 5);
    t.printInfo();

    myShape::Rectengle r(4, 3);
    r.printInfo();

    myShape::Circle c(2);
    c.printInfo();

    return 0;
}