module ModelRunner
  class PayloadAdapter
    class << self
      def normalize(raw_payload)
        payload = stringify_keys(raw_payload || {})
        return payload if payload.key?("results")

        results = {}
        results["shot_summary"] = payload["shot_summary"] if payload["shot_summary"].is_a?(Hash)
        results["form_analysis"] = payload["form_analysis"] if payload["form_analysis"].is_a?(Hash)
        results["coaching_summary"] = payload["coaching_summary"] if payload["coaching_summary"].is_a?(Hash)

        {
          "input" => payload["input"].is_a?(Hash) ? payload["input"] : {},
          "feedback" => payload["feedback"],
          "feedback_error" => payload["feedback_error"],
          "results" => results
        }
      end

      def summary_for(payload)
        p = stringify_keys(payload || {})
        feedback = p["feedback"].to_s.strip
        return feedback if feedback.present?

        coaching = p.dig("results", "coaching_summary")
        return nil unless coaching.is_a?(Hash)

        overall = coaching["overall"].is_a?(Hash) ? coaching["overall"] : {}
        lines = []

        mean_contact = overall["mean_contact"]
        n_scored = overall["n_scored"]
        if mean_contact
          if n_scored
            lines << "ReadyScore at contact: #{format('%.1f', mean_contact)}/100 across #{n_scored} shots."
          else
            lines << "ReadyScore at contact: #{format('%.1f', mean_contact)}/100."
          end
        end

        recommendations = Array(coaching["recommendations"]).compact.map(&:to_s).map(&:strip).reject(&:blank?)
        if recommendations.any?
          lines << "Top focus areas:"
          recommendations.first(2).each { |rec| lines << "- #{rec}" }
        end

        lines.presence&.join("\n")
      end

      private

      def stringify_keys(value)
        case value
        when Hash
          value.transform_keys(&:to_s).transform_values { |v| stringify_keys(v) }
        when Array
          value.map { |v| stringify_keys(v) }
        else
          value
        end
      end
    end
  end
end
