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
import { useState } from 'react';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_uses,
    ink_color,
    body_parts,
    current_step,
  } = data;

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
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Available Body Parts">
          {body_parts.length === 0 ? (
            <Box color="bad" textAlign="center">
              No available body parts found!
            </Box>
          ) : (
            <Stack vertical>
              {body_parts.map((part) => (
                <Stack.Item key={part.zone}>
                  <Button
                    fluid
                    disabled={part.covered || ink_uses <= 0}
                    onClick={() => act('select_bodypart', { zone: part.zone })}
                    color={part.covered ? 'bad' : 'default'}
                  >
                    <Stack>
                      <Stack.Item grow>
                        {part.name} ({part.current_tattoos}/{part.max_tattoos})
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
  const { ink_color, selected_zone_name, selected_layer } = data;

  // Use React state - this is the CORRECT pattern
  const [artistName, setArtistName] = useState('');
  const [tattooDesign, setTattooDesign] = useState('');

  const handleApplyTattoo = () => {
    // Trim values before sending
    const trimmedArtist = artistName.trim();
    const trimmedDesign = tattooDesign.trim();

    // Validate
    if (!trimmedArtist) {
      return;
    }
    if (!trimmedDesign) {
      return;
    }

    // Send the data with CORRECT parameter names
    act('apply_tattoo', {
      artist: trimmedArtist,
      design: trimmedDesign,
    });
  };

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
        <Section
          title={`Design Tattoo for ${selected_zone_name}`}
          buttons={
            <Button icon="arrow-left" onClick={() => act('back_to_selection')}>
              Back
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Artist Name">
              <Input
                fluid
                placeholder="Enter your name or signature..."
                value={artistName}
                onChange={(e, value) => setArtistName(value)}
                maxLength={50}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Tattoo Design">
              <TextArea
                fluid
                height="150px"
                placeholder="Describe the tattoo design in detail. Be creative!"
                value={tattooDesign}
                onChange={(e, value) => setTattooDesign(value)}
                maxLength={500}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Button
                icon="palette"
                onClick={() => act('change_ink_color')}
                tooltip="Change ink color"
              />
              <Box
                inline
                ml={1}
                style={{
                  width: '24px',
                  height: '24px',
                  backgroundColor: ink_color,
                  border: '2px solid #000',
                }}
              />
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
              {/* FIXED: Use the handler function with correct parameter names */}
              <Button
                fluid
                icon="check"
                color="good"
                onClick={handleApplyTattoo}
                tooltip="Apply the tattoo to the selected body part"
              >
                Apply Tattoo
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
