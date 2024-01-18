# distutils: language = c
# cython: language_level=3, wraparound=False, cdivision=True, boundscheck=False

ctypedef float[:, :] float2d
ctypedef double[:, :] double2d

ctypedef fused Streamline:
    float2d
    double2d


cdef void c_arclengths(Streamline streamline, double * out) noexcept nogil

cdef void c_set_number_of_points(Streamline streamline, Streamline out) noexcept nogil
