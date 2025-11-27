package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
)

// SubscriptionConfig represents a single Xray configuration from subscription
type SubscriptionConfig struct {
	Remarks   string                   `json:"remarks"`
	Inbounds  []map[string]interface{} `json:"inbounds"`
	Outbounds []map[string]interface{} `json:"outbounds"`
	Routing   map[string]interface{}   `json:"routing,omitempty"`
	DNS       map[string]interface{}   `json:"dns,omitempty"`
}

// InboundConfig represents the inbound configuration from environment
type InboundConfig struct {
	Protocol string `json:"protocol"`
	Port     int    `json:"port"`
	Tag      string `json:"tag"`
	Name     string `json:"name"`
}

// XrayConfig represents the complete Xray configuration
type XrayConfig struct {
	Log       LogConfig                  `json:"log"`
	API       *APIConfig                 `json:"api,omitempty"`
	Stats     map[string]interface{}     `json:"stats,omitempty"`
	Policy    *PolicyConfig              `json:"policy,omitempty"`
	Inbounds  []Inbound                  `json:"inbounds"`
	Outbounds []map[string]interface{}   `json:"outbounds"`
	Routing   RoutingConfig              `json:"routing"`
}

// APIConfig represents Xray API configuration
type APIConfig struct {
	Tag      string   `json:"tag"`
	Services []string `json:"services"`
}

// PolicyConfig represents Xray policy configuration
type PolicyConfig struct {
	Levels map[string]interface{}   `json:"levels,omitempty"`
	System map[string]interface{}   `json:"system,omitempty"`
}

// LogConfig represents Xray log configuration
type LogConfig struct {
	Error    string `json:"error"`
	Access   string `json:"access"`
	LogLevel string `json:"loglevel"`
}

// Inbound represents an Xray inbound
type Inbound struct {
	Tag      string                 `json:"tag"`
	Port     int                    `json:"port"`
	Protocol string                 `json:"protocol"`
	Listen   string                 `json:"listen"`
	Settings map[string]interface{} `json:"settings"`
}



// RoutingConfig represents Xray routing configuration
type RoutingConfig struct {
	DomainStrategy string        `json:"domainStrategy"`
	Rules          []RoutingRule `json:"rules"`
}

// RoutingRule represents a routing rule
type RoutingRule struct {
	Type        string   `json:"type"`
	InboundTag  []string `json:"inboundTag"`
	OutboundTag string   `json:"outboundTag"`
}

func logMsg(msg string) {
	log.Printf("[Go] %s", msg)
}

func main() {
	// Parse command line flags
	subscriptionFile := flag.String("subscription", getEnv("SUBSCRIPTION_FILE", "/opt/xraymulti/config/subscription.json"), "订阅文件路径")
	xrayConfigFile := flag.String("config", getEnv("XRAY_CONFIG_FILE", "/etc/xray/config.json"), "Xray配置文件路径")
	xrayLogLevel := flag.String("loglevel", getEnv("XRAY_LOG_LEVEL", "warning"), "日志级别")
	inboundsJSON := flag.String("inbounds", getEnv("INBOUNDS_JSON", "[]"), "入站配置JSON")
	apiListen := flag.String("api-listen", getEnv("API_LISTEN", "127.0.0.1"), "API监听地址")
	apiPort := flag.String("api-port", getEnv("API_PORT", "8080"), "API监听端口")
	flag.Parse()

	// Read subscription file
	subscriptionConfigs, err := readSubscriptionConfig(*subscriptionFile)
	if err != nil {
		logMsg(fmt.Sprintf("错误: 无法读取订阅文件 - %v", err))
		os.Exit(1)
	}

	if len(subscriptionConfigs) == 0 {
		logMsg("错误: 订阅中没有找到配置节点")
		os.Exit(1)
	}

	logMsg(fmt.Sprintf("找到 %d 个配置节点", len(subscriptionConfigs)))

	// Create remarks to config map
	remarksMap := make(map[string]*SubscriptionConfig)
	for idx := range subscriptionConfigs {
		config := &subscriptionConfigs[idx]
		if config.Remarks != "" {
			remarksMap[config.Remarks] = config
			logMsg(fmt.Sprintf("配置 [%d]: %s (%d个出站)", idx, config.Remarks, len(config.Outbounds)))
		}
	}

	// Parse inbounds configuration
	var inboundsConfig []InboundConfig
	if err := json.Unmarshal([]byte(*inboundsJSON), &inboundsConfig); err != nil {
		logMsg(fmt.Sprintf("错误: 无法解析入站配置JSON - %v", err))
		os.Exit(1)
	}

	if len(inboundsConfig) == 0 {
		logMsg("错误: 没有配置入站")
		os.Exit(1)
	}

	// Build inbounds and mapping
	var inbounds []Inbound
	var inboundOutboundMap []struct {
		InboundTag   string
		TargetConfig *SubscriptionConfig
	}

	// Add API inbound (first)
	apiPortInt := 8080
	if port, err := parseIntFromString(*apiPort); err == nil {
		apiPortInt = port
	}
	apiInbound := Inbound{
		Tag:      "api-in",
		Listen:   *apiListen,
		Port:     apiPortInt,
		Protocol: "dokodemo-door",
		Settings: map[string]interface{}{
			"address": "127.0.0.1",
		},
	}
	inbounds = append(inbounds, apiInbound)
	logMsg(fmt.Sprintf("API入站: %s:%d", *apiListen, apiPortInt))

	for _, inboundCfg := range inboundsConfig {
		if inboundCfg.Protocol == "" || inboundCfg.Port == 0 || inboundCfg.Tag == "" {
			logMsg(fmt.Sprintf("警告: 跳过无效的入站配置: %+v", inboundCfg))
			continue
		}

		// Create inbound
		inbound := Inbound{
			Tag:      inboundCfg.Tag,
			Port:     inboundCfg.Port,
			Protocol: inboundCfg.Protocol,
			Listen:   "0.0.0.0",
			Settings: make(map[string]interface{}),
		}

		// Configure based on protocol
		if inboundCfg.Protocol == "socks" {
			inbound.Settings["auth"] = "noauth"
			inbound.Settings["udp"] = true
		}

		inbounds = append(inbounds, inbound)

		// Find target config by remarks
		var targetConfig *SubscriptionConfig
		if inboundCfg.Name != "" {
			if config, exists := remarksMap[inboundCfg.Name]; exists {
				targetConfig = config
				logMsg(fmt.Sprintf("入站 %s (%s:%d) -> 配置: %s", inboundCfg.Tag, inboundCfg.Protocol, inboundCfg.Port, inboundCfg.Name))
			} else {
				logMsg(fmt.Sprintf("警告: 入站 %s 未找到匹配配置 '%s'", inboundCfg.Tag, inboundCfg.Name))
			}
		}

		inboundOutboundMap = append(inboundOutboundMap, struct {
			InboundTag   string
			TargetConfig *SubscriptionConfig
		}{
			InboundTag:   inboundCfg.Tag,
			TargetConfig: targetConfig,
		})
	}

	if len(inbounds) == 0 {
		logMsg("错误: 没有有效的入站配置")
		os.Exit(1)
	}

	// Extract outbounds from subscription configs
	var outbounds []map[string]interface{}
	outboundIndex := 0

	for _, mapping := range inboundOutboundMap {
		if mapping.TargetConfig != nil && len(mapping.TargetConfig.Outbounds) > 0 {
			// 获取第一个 proxy 出站（通常 tag 为 "proxy"）
			for _, outbound := range mapping.TargetConfig.Outbounds {
				if tag, ok := outbound["tag"].(string); ok && tag == "proxy" {
					// 修改 tag 为唯一标识
					newTag := fmt.Sprintf("outbound_%d", outboundIndex)
					outboundCopy := make(map[string]interface{})
					for k, v := range outbound {
						outboundCopy[k] = v
					}
					outboundCopy["tag"] = newTag
					outbounds = append(outbounds, outboundCopy)
					logMsg(fmt.Sprintf("提取出站: %s -> %s (来自 %s)", tag, newTag, mapping.TargetConfig.Remarks))
					outboundIndex++
					break
				}
			}
		}
	}

	if len(outbounds) == 0 {
		logMsg("错误: 没有成功提取的出站节点")
		os.Exit(1)
	}

	// Add necessary outbounds
	outbounds = append(outbounds, map[string]interface{}{
		"tag":      "direct",
		"protocol": "freedom",
	})

	outbounds = append(outbounds, map[string]interface{}{
		"tag":      "block",
		"protocol": "blackhole",
	})

	// Create routing rules
	var routingRules []RoutingRule

	// Add API routing rule (must be first)
	apiRule := RoutingRule{
		Type:        "field",
		InboundTag:  []string{"api-in"},
		OutboundTag: "api",
	}
	routingRules = append(routingRules, apiRule)
	logMsg("路由规则: api-in -> api")

	outboundIdx := 0
	for _, mapping := range inboundOutboundMap {
		if mapping.TargetConfig != nil && outboundIdx < len(outbounds)-2 {
			if tag, ok := outbounds[outboundIdx]["tag"].(string); ok {
				routingRules = append(routingRules, RoutingRule{
					Type:        "field",
					InboundTag:  []string{mapping.InboundTag},
					OutboundTag: tag,
				})
				logMsg(fmt.Sprintf("路由规则: %s -> %s", mapping.InboundTag, tag))
				outboundIdx++
			}
		}
	}

	// Build complete Xray configuration
	xrayConfig := XrayConfig{
		Log: LogConfig{
			Error:    "/var/log/xraymulti/error.log",
			Access:   "/var/log/xraymulti/access.log",
			LogLevel: *xrayLogLevel,
		},
		API: &APIConfig{
			Tag: "api",
			Services: []string{
				"HandlerService",
				"LoggerService",
				"StatsService",
			},
		},
		Stats: map[string]interface{}{},
		Policy: &PolicyConfig{
			Levels: map[string]interface{}{
				"0": map[string]interface{}{
					"statsUserUplink":   true,
					"statsUserDownlink": true,
				},
			},
			System: map[string]interface{}{
				"statsInboundUplink":    true,
				"statsInboundDownlink":  true,
				"statsOutboundUplink":   true,
				"statsOutboundDownlink": true,
			},
		},
		Inbounds:  inbounds,
		Outbounds: outbounds,
		Routing: RoutingConfig{
			DomainStrategy: "AsIs",
			Rules:          routingRules,
		},
	}

	// Save configuration
	if err := saveXrayConfig(*xrayConfigFile, xrayConfig); err != nil {
		logMsg(fmt.Sprintf("错误: 无法保存配置文件 - %v", err))
		os.Exit(1)
	}

	logMsg(fmt.Sprintf("配置已保存到: %s", *xrayConfigFile))
	logMsg(fmt.Sprintf("转换完成: %d 个入站, %d 个出站", len(inbounds), len(outbounds)-2))
}

func readSubscriptionConfig(filename string) ([]SubscriptionConfig, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	var configs []SubscriptionConfig
	if err := json.Unmarshal(data, &configs); err != nil {
		return nil, err
	}

	return configs, nil
}

func saveXrayConfig(filename string, config XrayConfig) error {
	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}

	return os.WriteFile(filename, data, 0644)
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func parseIntFromString(s string) (int, error) {
	var result int
	_, err := fmt.Sscanf(s, "%d", &result)
	return result, err
}
