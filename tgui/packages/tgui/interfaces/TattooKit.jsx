import {
  Box,
  Button,
  Input,
  LabeledList,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';
import { useState, useEffect } from 'react';

export const TattooKit = (props) => {
  const { act, data } = useBackend();

  // Safe destructuring with defaults
  const {
    target_name = "Unknown",
    ink_uses = 0,
    max_uses = 50,
    ink_color = "#000000",
    body_parts = [],
    current_step = "select_part",
    selected_zone_name = "Unknown",
    selected_layer = 2,
  } = data || {};

  if (current_step === 'design_tattoo') {
    return <DesignTattooStep />;
  }

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
        <Section title={`Tattooing: ${target_name}`}>
          <LabeledList>
            <LabeledList.Item label="Ink Remaining">
              <Box color={ink_uses > 0 ? 'good' : 'bad'}>
                {ink_uses}/{max_uses} uses
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Button
                icon="palette"
                content="Change Color"
                onClick={() => act('change_ink_color')}
              />
              <Box
                inline
                ml={1}
                style={{
                  width: '20px',
                  height: '20px',
                  backgroundColor: ink_color,
                  border: '1px solid #000',
                }}
              />
              <Box inline ml={1}>
                {ink_color}
              </Box>
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Available Body Parts">
          {!body_parts || body_parts.length === 0 ? (
            <Box color="bad" textAlign="center">
              No available body parts found!
            </Box>
          ) : (
            <Stack vertical>
              {body_parts.map((part) => (
                <Stack.Item key={part.zone || "unknown"}>
                  <Button
                    fluid
                    disabled={part.covered || ink_uses <= 0}
                    onClick={() => act('select_bodypart', {
                      zone: part.zone || "chest"
                    })}
                    color={part.covered ? 'bad' : 'default'}
                  >
                    <Stack>
                      <Stack.Item grow>
                        {part.name || "Unknown"}
                        ({part.current_tattoos || 0}/{part.max_tattoos || 5})
                      </Stack.Item>
                      <Stack.Item>
                        {part.covered ? '🔒 Covered' : '🔓 Exposed'}
                      </Stack.Item>
                    </Stack>
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};

const DesignTattooStep = (props) => {
  const { act, data } = useBackend();

  // Safe destructuring with defaults
  const {
    ink_color = "#000000",
    selected_zone_name = "Unknown",
    selected_layer = 2,
    ink_uses = 0
  } = data || {};

  const [artistName, setArtistName] = useState('');
  const [tattooDesign, setTattooDesign] = useState('');
  const [canApply, setCanApply] = useState(false);

  // Enhanced validation
  useEffect(() => {
    const trimmedArtist = (artistName || '').trim();
    const trimmedDesign = (tattooDesign || '').trim();

    const hasArtist = trimmedArtist.length > 0;
    const hasDesign = trimmedDesign.length > 0;
    const hasInk = (ink_uses || 0) > 0;

    setCanApply(hasArtist && hasDesign && hasInk);
  }, [artistName, tattooDesign, ink_uses]);

  const handleApplyTattoo = (e) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    if (!canApply) {
      return;
    }

    const trimmedArtist = (artistName || '').trim();
    const trimmedDesign = (tattooDesign || '').trim();

    // Final safety check
    if (!trimmedArtist || !trimmedDesign) {
      return;
    }

    act('apply_tattoo', {
      artist: trimmedArtist,
      design: trimmedDesign,
    });
  };

  const handleArtistChange = (e, value) => {
    setArtistName(value || '');
  };

  const handleDesignChange = (e, value) => {
    setTattooDesign(value || '');
  };

  // Real-time validation for UI feedback
  const isArtistValid = (artistName || '').trim().length > 0;
  const isDesignValid = (tattooDesign || '').trim().length > 0;
  const hasInk = (ink_uses || 0) > 0;

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
        <Section
          title={`Design Tattoo for ${selected_zone_name}`}
          buttons={
            <Button
              icon="arrow-left"
              onClick={() => act('back_to_selection')}
            >
              Back
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item
              label="Artist Name"
            >
              <Input
                fluid
                placeholder="Enter your name or signature..."
                value={artistName}
                onChange={handleArtistChange}
                maxLength={50}
              />
            </LabeledList.Item>
            <LabeledList.Item
              label="Tattoo Design"
            >
              <TextArea
                fluid
                height="150px"
                placeholder="Describe the tattoo design in detail. Be creative!"
                value={tattooDesign}
                onChange={handleDesignChange}
                maxLength={500}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Stack>
                <Stack.Item>
                  <Button
                    icon="palette"
                    onClick={() => act('change_ink_color')}
                    tooltip="Change ink color"
                  />
                </Stack.Item>
                <Stack.Item>
                  <Box
                    style={{
                      width: '24px',
                      height: '24px',
                      backgroundColor: ink_color,
                      border: '2px solid #000',
                      marginLeft: '5px',
                    }}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Box ml={1}>
                    {ink_color}
                  </Box>
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
            <LabeledList.Item label="Layer">
              <Stack>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 1}
                    onClick={() => act('set_layer', { layer: 1 })}
                  >
                    Under
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 2}
                    onClick={() => act('set_layer', { layer: 2 })}
                  >
                    Normal
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 3}
                    onClick={() => act('set_layer', { layer: 3 })}
                  >
                    Over
                  </Button>
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
            <LabeledList.Item>
              <Button
                fluid
                icon="check"
                color={canApply ? "good" : "bad"}
                disabled={!canApply}
                onClick={handleApplyTattoo}
                tooltip={
                  !canApply
                    ? `Fill out all fields${!hasInk ? ' and ensure ink is available' : ''}`
                    : "Apply the tattoo to the selected body part"
                }
              >
                {canApply ? "Apply Tattoo" : `Fill Required Fields${!hasInk ? ' (No Ink)' : ''}`}
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
