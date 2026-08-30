# =============================================================================
# WAFv2 web ACL, regional scope, associated with the Application Load Balancer.
#
# Rule order matters — rules evaluate by priority, lowest first, and the first
# terminating action wins:
#
#   10  rate limit          blunt DoS / scraping brake
#   20  IP reputation       known malicious sources
#   30  common rule set     OWASP-ish baseline (XSS, LFI, bad bots)
#   40  bad inputs          exploitable request patterns
#   50  SQL injection       dedicated SQLi rules
#   60  geo block           optional, off by default
# =============================================================================

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name}-waf"
  description = "Edge protection for ${var.name}"
  scope       = "REGIONAL"
  tags        = var.tags

  default_action {
    allow {}
  }

  # ---- 10: rate limiting -----------------------------------------------
  rule {
    name     = "rate-limit"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # ---- 20-50: AWS managed rule groups ----------------------------------
  dynamic "rule" {
    for_each = {
      "AWSManagedRulesAmazonIpReputationList" = 20
      "AWSManagedRulesCommonRuleSet"          = 30
      "AWSManagedRulesKnownBadInputsRuleSet"  = 40
      "AWSManagedRulesSQLiRuleSet"            = 50
    }

    content {
      name     = rule.key
      priority = rule.value

      override_action {
        dynamic "count" {
          for_each = var.count_mode ? [1] : []
          content {}
        }
        dynamic "none" {
          for_each = var.count_mode ? [] : [1]
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.key
          vendor_name = "AWS"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = rule.key
        sampled_requests_enabled   = true
      }
    }
  }

  # ---- 60: optional geo block ------------------------------------------
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []

    content {
      name     = "geo-block"
      priority = 60

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name}-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# -------------------------------------------------------------------------
# Logging. The log group name MUST start with aws-waf-logs- or the
# PutLoggingConfiguration call is rejected.
# -------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  # Never log credentials that appear in a blocked request.
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
