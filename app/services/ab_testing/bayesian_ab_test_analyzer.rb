module AbTesting
  class BayesianAbTestAnalyzer
    def initialize(ab_test)
      @ab_test = ab_test
    end

    def analyze_with_priors(prior_beliefs, observed_data)
      posterior_distributions = calculate_posterior_distributions(prior_beliefs, observed_data)

      {
        posterior_distributions: posterior_distributions,
        probability_treatment_better: calculate_probability_treatment_better(posterior_distributions),
        expected_loss_control: calculate_expected_loss(posterior_distributions, :control),
        expected_loss_treatment: calculate_expected_loss(posterior_distributions, :treatment),
        credible_intervals: calculate_credible_intervals(posterior_distributions),
        bayes_factor: calculate_bayes_factor(prior_beliefs, observed_data)
      }
    end

    def calculate_probability_treatment_better(posterior_distributions)
      # Calculate probability that treatment is better than control
      return 0.5 unless posterior_distributions[:control] && posterior_distributions[:treatment]

      control_params = posterior_distributions[:control]
      treatment_params = posterior_distributions[:treatment]

      # Use Monte Carlo simulation to estimate probability
      n_samples = 10000
      better_count = 0

      n_samples.times do
        # Sample from Beta distributions
        control_sample = beta_sample(control_params[:alpha], control_params[:beta])
        treatment_sample = beta_sample(treatment_params[:alpha], treatment_params[:beta])

        better_count += 1 if treatment_sample > control_sample
      end

      (better_count.to_f / n_samples).round(4)
    end

    def calculate_posterior_distributions(prior_beliefs, observed_data)
      posteriors = {}

      observed_data.each do |variant_key, data|
        prior_key = "#{variant_key}_conversion_rate".to_sym
        prior = prior_beliefs[prior_key] || { alpha: 1, beta: 1 }  # Uniform prior

        conversions = data[:conversions] || 0
        visitors = data[:visitors] || 0
        non_conversions = visitors - conversions

        # Beta-Binomial conjugate prior
        posterior_alpha = prior[:alpha] + conversions
        posterior_beta = prior[:beta] + non_conversions

        posteriors[variant_key] = {
          alpha: posterior_alpha,
          beta: posterior_beta,
          mean: posterior_alpha.to_f / (posterior_alpha + posterior_beta),
          variance: (posterior_alpha * posterior_beta).to_f /
                   ((posterior_alpha + posterior_beta) ** 2 * (posterior_alpha + posterior_beta + 1))
        }
      end

      posteriors
    end

    def calculate_probability_of_superiority(posteriors)
      return 0.5 unless posteriors.keys.length == 2

      control_key = posteriors.keys.first
      treatment_key = posteriors.keys.last

      control = posteriors[control_key]
      treatment = posteriors[treatment_key]

      # Monte Carlo simulation for P(treatment > control)
      simulation_count = 10000
      treatment_wins = 0

      simulation_count.times do
        control_sample = beta_sample(control[:alpha], control[:beta])
        treatment_sample = beta_sample(treatment[:alpha], treatment[:beta])

        treatment_wins += 1 if treatment_sample > control_sample
      end

      treatment_wins.to_f / simulation_count
    end

    def calculate_expected_loss(posteriors, variant_key)
      return 0 unless posteriors[variant_key]

      other_variants = posteriors.reject { |k, _| k == variant_key }
      return 0 if other_variants.empty?

      # Expected loss if we choose this variant but another is actually better
      variant_dist = posteriors[variant_key]

      # Simplified expected loss calculation
      expected_losses = other_variants.map do |other_key, other_dist|
        prob_other_better = calculate_pairwise_probability(other_dist, variant_dist)
        expected_difference = [ other_dist[:mean] - variant_dist[:mean], 0 ].max

        prob_other_better * expected_difference
      end

      expected_losses.sum.round(6)
    end

    def calculate_credible_intervals(posteriors, confidence_level = 0.95)
      intervals = {}
      alpha = (1 - confidence_level) / 2

      posteriors.each do |variant_key, dist|
        # For Beta distribution, calculate quantiles
        lower_bound = beta_quantile(dist[:alpha], dist[:beta], alpha)
        upper_bound = beta_quantile(dist[:alpha], dist[:beta], 1 - alpha)

        intervals[variant_key] = {
          lower_bound: lower_bound.round(4),
          upper_bound: upper_bound.round(4),
          mean: dist[:mean].round(4),
          confidence_level: confidence_level
        }
      end

      intervals
    end

    def calculate_bayes_factor(prior_beliefs, observed_data)
      # Simplified Bayes Factor calculation
      # Compares evidence for H1 (difference exists) vs H0 (no difference)

      return 1.0 unless observed_data.keys.length == 2

      control_key = observed_data.keys.first
      treatment_key = observed_data.keys.last

      control_data = observed_data[control_key]
      treatment_data = observed_data[treatment_key]

      # Calculate marginal likelihoods (simplified)
      control_rate = control_data[:conversions].to_f / control_data[:visitors] rescue 0
      treatment_rate = treatment_data[:conversions].to_f / treatment_data[:visitors] rescue 0

      rate_difference = (treatment_rate - control_rate).abs

      # Simplified BF based on effect size and sample size
      total_sample_size = control_data[:visitors] + treatment_data[:visitors]

      if rate_difference > 0.02 && total_sample_size > 200
        # Evidence for H1 (difference exists)
        bayes_factor = [ rate_difference * total_sample_size / 100, 1.0 ].max
      else
        # Evidence for H0 (no meaningful difference)
        bayes_factor = 1.0 / [ rate_difference * total_sample_size / 100 + 1, 2.0 ].max
      end

      {
        value: bayes_factor.round(2),
        interpretation: interpret_bayes_factor(bayes_factor),
        evidence_strength: bayes_factor_evidence_strength(bayes_factor)
      }
    end

    private

    def beta_sample(alpha, beta)
      # Simple beta distribution sampling using transformation method
      # Generate two gamma samples and use the ratio
      gamma1 = gamma_sample(alpha)
      gamma2 = gamma_sample(beta)

      gamma1 / (gamma1 + gamma2)
    end

    def gamma_sample(shape, scale = 1.0)
      # Simplified gamma sampling using acceptance-rejection for shape > 1
      # For shape < 1, use transformation

      if shape >= 1
        # Use Marsaglia and Tsang's method (simplified)
        d = shape - 1.0/3.0
        c = 1.0 / Math.sqrt(9.0 * d)

        loop do
          x = standard_normal_sample
          v = (1.0 + c * x) ** 3
          next if v <= 0

          u = rand
          x_squared = x * x

          if u < 1.0 - 0.0331 * x_squared * x_squared
            return d * v * scale
          end

          if Math.log(u) < 0.5 * x_squared + d * (1.0 - v + Math.log(v))
            return d * v * scale
          end
        end
      else
        # For shape < 1, use transformation
        gamma_sample(shape + 1) * (rand ** (1.0 / shape)) * scale
      end
    end

    def standard_normal_sample
      # Box-Muller transformation
      @cached_normal ||= nil

      if @cached_normal
        result = @cached_normal
        @cached_normal = nil
        return result
      end

      u1 = rand
      u2 = rand

      z1 = Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math::PI * u2)
      z2 = Math.sqrt(-2.0 * Math.log(u1)) * Math.sin(2.0 * Math::PI * u2)

      @cached_normal = z2
      z1
    end

    def calculate_pairwise_probability(dist1, dist2)
      # Probability that dist1 > dist2
      # Using analytical solution for Beta distributions

      # Monte Carlo approximation
      simulations = 1000
      wins = 0

      simulations.times do
        sample1 = beta_sample(dist1[:alpha], dist1[:beta])
        sample2 = beta_sample(dist2[:alpha], dist2[:beta])
        wins += 1 if sample1 > sample2
      end

      wins.to_f / simulations
    end

    def beta_quantile(alpha, beta, p)
      # Approximate beta quantile using Newton-Raphson method
      # For simplicity, using a lookup table approximation

      mean = alpha.to_f / (alpha + beta)

      # Simple approximation based on normal approximation to beta
      variance = (alpha * beta).to_f / ((alpha + beta) ** 2 * (alpha + beta + 1))
      std_dev = Math.sqrt(variance)

      # Normal approximation quantile
      z_score = inverse_normal_cdf(p)
      quantile = mean + z_score * std_dev

      # Clamp to [0, 1]
      [ [ quantile, 0 ].max, 1 ].min
    end

    def inverse_normal_cdf(p)
      # Approximate inverse normal CDF
      # Using Beasley-Springer-Moro algorithm approximation

      return -inverse_normal_cdf(1 - p) if p > 0.5

      if p < 1e-10
        return -10  # Very negative value
      end

      # Rational approximation coefficients
      a = [ 0, -3.969683028665376e+01, 2.209460984245205e+02,
           -2.759285104469687e+02, 1.383577518672690e+02,
           -3.066479806614716e+01, 2.506628277459239e+00 ]

      b = [ 0, -5.447609879822406e+01, 1.615858368580409e+02,
           -1.556989798598866e+02, 6.680131188771972e+01,
           -1.328068155288572e+01 ]

      if p < 0.5
        q = Math.sqrt(-2 * Math.log(p))
        numerator = a[6]
        (5).downto(1) { |i| numerator = numerator * q + a[i] }
        denominator = b[1]
        (2..5).each { |i| denominator = denominator * q + b[i] }

        return -(q - numerator / denominator)
      end

      0  # Fallback
    end

    def interpret_bayes_factor(bf)
      case bf
      when 0..1
        "Evidence for no difference"
      when 1..3
        "Weak evidence for difference"
      when 3..10
        "Moderate evidence for difference"
      when 10..30
        "Strong evidence for difference"
      when 30..100
        "Very strong evidence for difference"
      else
        "Extreme evidence for difference"
      end
    end

    def bayes_factor_evidence_strength(bf)
      case bf
      when 0..1 then "none"
      when 1..3 then "weak"
      when 3..10 then "moderate"
      when 10..30 then "strong"
      when 30..100 then "very_strong"
      else "extreme"
      end
    end
  end
end
