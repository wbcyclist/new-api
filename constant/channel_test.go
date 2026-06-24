package constant

import (
	"testing"
)

func TestChannelTypeVolcAdapterRegistration(t *testing.T) {
	// Verify the constant value is 58 (next available after ChannelTypeCodex=57).
	if ChannelTypeVolcAdapter != 58 {
		t.Errorf("expected ChannelTypeVolcAdapter=58, got %d", ChannelTypeVolcAdapter)
	}

	if ChannelTypeAdvancedCustom != 59 {
		t.Errorf("expected ChannelTypeAdvancedCustom=59, got %d", ChannelTypeAdvancedCustom)
	}

	// ChannelTypeDummy is explicitly assigned to equal the highest defined
	// channel type. When adding a new channel type, append
	// it after the last existing one with an explicit numeric value, then update
	// ChannelTypeDummy to equal the new highest. The explicit assignment avoids
	// confusion with iota's implicit-repeat semantics.
	if ChannelTypeDummy != ChannelTypeAdvancedCustom {
		t.Errorf("expected ChannelTypeDummy == ChannelTypeAdvancedCustom (%d), got %d",
			ChannelTypeAdvancedCustom, ChannelTypeDummy)
	}
}

func TestChannelTypeVolcAdapterDisplayName(t *testing.T) {
	name := GetChannelTypeName(ChannelTypeVolcAdapter)
	if name != "VolcAdapter" {
		t.Errorf("expected display name %q, got %q", "VolcAdapter", name)
	}
}

func TestChannelTypeVolcAdapterBaseURL(t *testing.T) {
	const wantURL = "https://ark.cn-beijing.volces.com"
	if ChannelTypeVolcAdapter >= len(ChannelBaseURLs) {
		t.Fatalf("ChannelBaseURLs too short: len=%d, ChannelTypeVolcAdapter=%d", len(ChannelBaseURLs), ChannelTypeVolcAdapter)
	}
	got := ChannelBaseURLs[ChannelTypeVolcAdapter]
	if got != wantURL {
		t.Errorf("expected base URL %q, got %q", wantURL, got)
	}
}

// TestChannelBaseURLsLength verifies the ChannelBaseURLs slice covers all channel
// types through ChannelTypeDummy, so no index-out-of-bounds can occur.
func TestChannelBaseURLsLength(t *testing.T) {
	if len(ChannelBaseURLs) < ChannelTypeDummy+1 {
		t.Errorf("ChannelBaseURLs has %d entries but needs at least %d to cover ChannelTypeDummy=%d",
			len(ChannelBaseURLs), ChannelTypeDummy+1, ChannelTypeDummy)
	}
}

func TestChannelTypeVolcAdapterInNames(t *testing.T) {
	if _, ok := ChannelTypeNames[ChannelTypeVolcAdapter]; !ok {
		t.Errorf("ChannelTypeVolcAdapter (%d) not found in ChannelTypeNames map", ChannelTypeVolcAdapter)
	}
}
