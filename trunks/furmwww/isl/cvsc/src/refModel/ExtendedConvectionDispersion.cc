#include "ExtendedConvectionDispersion.h"

double ExtendedConvectionDispersion::ecd(double z, double t) {
  return this->ecd(t); // ignore z in ecd model
}

// Time domain
double ExtendedConvectionDispersion::ecd(double t)
{

  // Perform numerical inverse laplace transform on l_ecd.
  std::complex<double> i(0,1);
  
  std::complex<double> pi_c(3.14159265358979323, 0);

  std::complex<double> int_sum(0,0);

  std::complex<double> increment(0, INTEGRATION_DW);

  std::complex<double> t_c(t, 0);
  double x_contour = 1 / t; // contour of integration chosen to avoid numerical blowups

  for (std::complex<double> counter(x_contour, -INTEGRATION_INFINITY); imag(counter) < INTEGRATION_INFINITY; counter += increment) {
    std::complex<double> d_sum = (this->l_ecd(counter) * exp(counter * t_c) );
    int_sum += d_sum * INTEGRATION_DW;
  }
  int_sum = (int_sum / (2. * pi_c));

  return real(int_sum); // if we did the calc correctly, the imaginary part should be negligible
}

// Laplace domain
std::complex<double> ExtendedConvectionDispersion::l_ecd(std::complex <double> s)
{
  if (this->extracting)
    return (this->M/this->Q)   *   (exp( (1. - sqrt(1. + (4 * this->D * this->T * (s + this->g(s))) )) / ( 2 * this->D) ));
  else
    return (this->M/this->Q)   *   (exp( (1. - sqrt(1. + (4 * this->D * this->T * (s + this->a - this->a*this->b/(s + this->b)  )) )) / ( 2 * this->D) ));
}

std::complex<double> ExtendedConvectionDispersion::g(std::complex<double> s) {
  std::complex<double> g_sum = 0;
  g_sum += this->k_1;
  g_sum -= ((this->k_1 * this->k_2) / (s + this->k_e + this->k_2));
  g_sum += this->a;
  g_sum -= ((this->a * this->b) / (s + this->k_1 + this->b - ((this->k_1 * this->k_2) / ( s + this->k_e + this->k_2))) );
  return g_sum;
}

