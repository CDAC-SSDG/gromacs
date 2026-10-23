#include <sycl/sycl.hpp>
#include <iostream>
#include <vector>
#include <iomanip>

using namespace sycl;
using namespace std;

int main() {
    size_t N = 100;

        queue q;

    int* vectorA = malloc_shared<int>(N, q);
    int* vectorB = malloc_shared<int>(N, q);
    int* result  = malloc_shared<int>(N, q);

    for (size_t i = 0; i < N; ++i) {
        vectorA[i] = i + 1;
        vectorB[i] = (i + 1) * 2;
    }

    q.submit([&](handler& cgh) {
        cgh.parallel_for<class vector_addition>(
            range<1>(N),
            [=](sycl::id<1> id) {
                size_t i = id[0];
                result[i] = vectorA[i] + vectorB[i];
            });
    });

    q.wait();

    free(vectorA, q);
    free(vectorB, q);
    free(result, q);

    return 0;
}

