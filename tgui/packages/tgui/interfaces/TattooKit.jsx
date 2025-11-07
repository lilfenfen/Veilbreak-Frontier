import { useState } from 'react';
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

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_uses,
    ink_color,
    body_parts,
    selected_zone,
    selected_zone_name,
    current_step,
    selected_layer = 2,
  } = data;

  // Use React state to manage input values locally (like chemistry examples)
  const [localArtistName, setLocalArtistName] = useState('');
  const [localTattooDesign, setLocalTattooDesign] = useState('');

  console.log('TATDAT: TattooKit render - current_step:', current_step,
    'localArtistName:', localArtistName, 'localTattooDesign:', localTattooDesign,
    'ink_uses:', ink_uses, 'selected_zone:', selected_zone);

  if (current_step === 'design_tattoo') {
    return (
      <DesignTattooStep
        localArtistName={localArtistName}
        setLocalArtistName={setLocalArtistName}
        localTattooDesign={localTattooDesign}
        setLocalTattooDesign={setLocalTattooDesign}
      />
    );
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
                  display: 'inline-block',
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
          {body_parts.length === 0 && (
            <Box color="bad" textAlign="center">
              {ink_uses <= 0
                ? 'Out of ink! Use a toner cartridge to refill.'
                : 'No available body parts found! Target may be fully clothed or have no valid body parts.'}
            </Box>
          )}
          <Stack vertical>
            {body_parts.map((part) => (
              <Stack.Item key={part.zone}>
                <Button
                  fluid
                  disabled={
                    part.covered ||
                    part.current_tattoos >= part.max_tattoos ||
                    ink_uses <= 0
                  }
                  onClick={() => {
                    console.log('TATDAT: Selecting bodypart:', part.zone);
                    act('select_bodypart', { zone: part.zone });
                  }}
                  tooltip={
                    part.covered
                      ? 'Body part is covered by clothing - expose it first!'
                      : part.current_tattoos >= part.max_tattoos
                        ? `Maximum tattoos reached for this part (${part.max_tattoos})`
                        : ink_uses <= 0
                          ? 'Out of ink - refill the kit first!'
                          : `Apply tattoo to ${part.name}`
                  }
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
        </Section>
      </Window.Content>
    </Window>
  );
};

const DesignTattooStep = (props) => {
  const { act, data } = useBackend();
  const {
    localArtistName,
    setLocalArtistName,
    localTattooDesign,
    setLocalTattooDesign,
  } = props;

  const {
    target_name,
    ink_color,
    selected_zone_name,
    selected_layer = 2,
  } = data;

  // Calculate can_apply based on local state (like chemistry examples)
  const can_apply = localArtistName && localArtistName.trim().length > 0 &&
                   localTattooDesign && localTattooDesign.trim().length > 0;

  console.log('TATDAT: DesignTattooStep render - localArtistName:', localArtistName,
    'localTattooDesign:', localTattooDesign, 'can_apply:', can_apply,
    'selected_zone_name:', selected_zone_name, 'selected_layer:', selected_layer);

  const handleApply = () => {
    console.log('TATDAT: Applying tattoo with artist:', localArtistName, 'design:', localTattooDesign);
    // Send both values to the DM in one action (like chemistry examples)
    act('apply_tattoo', {
      artist_name: localArtistName,
      tattoo_design: localTattooDesign,
    });
  };

  const handleBack = () => {
    // Clear local state when going back
    setLocalArtistName('');
    setLocalTattooDesign('');
    act('back_to_selection');
  };

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
        <Section
          title={`Design Tattoo for ${selected_zone_name}`}
          buttons={
            <Button icon="arrow-left" onClick={handleBack}>
              Back
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Artist Name">
              <Input
                fluid
                value={localArtistName}
                placeholder="Enter your name or signature..."
                onChange={(e, value) => {
                  console.log('TATDAT: Artist name changed to:', value);
                  setLocalArtistName(value);
                }}
                maxLength={50}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Tattoo Design">
              <TextArea
                fluid
                value={localTattooDesign}
                height="150px"
                placeholder="Describe the tattoo design in detail. Be creative!"
                onChange={(e, value) => {
                  console.log('TATDAT: Tattoo design changed to:', value);
                  setLocalTattooDesign(value);
                }}
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
                  display: 'inline-block',
                  width: '24px',
                  height: '24px',
                  backgroundColor: ink_color,
                  border: '2px solid #000',
                  borderRadius: '3px',
                }}
              />
              <Box inline ml={1} color="label">
                {ink_color}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Layer">
              <Stack>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 1}
                    onClick={() => {
                      console.log('TATDAT: Setting layer to 1');
                      act('update_tattoo_layer', { layer: 1 });
                    }}
                    tooltip="Under layer - appears behind other tattoos"
                  >
                    Under
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 2}
                    onClick={() => {
                      console.log('TATDAT: Setting layer to 2');
                      act('update_tattoo_layer', { layer: 2 });
                    }}
                    tooltip="Normal layer - standard placement"
                  >
                    Normal
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 3}
                    onClick={() => {
                      console.log('TATDAT: Setting layer to 3');
                      act('update_tattoo_layer', { layer: 3 });
                    }}
                    tooltip="Over layer - appears in front of other tattoos"
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
                color={can_apply ? 'good' : 'default'}
                disabled={!can_apply}
                onClick={handleApply}
                tooltip={
                  can_apply
                    ? 'Apply the tattoo to the selected body part'
                    : 'Fill in both artist name and tattoo design first'
                }
              >
                Apply Tattoo
              </Button>
            </LabeledList.Item>
            <LabeledList.Item label="Debug Info">
              <Box color="label" fontSize="0.8em">
                Artist: '{localArtistName}' (len: {localArtistName?.length || 0})<br />
                Design: '{localTattooDesign?.substring(0, 50) || ''}' (len: {localTattooDesign?.length || 0})<br />
                Can Apply: {can_apply ? 'YES' : 'NO'}<br />
                Zone: {selected_zone_name}<br />
                Layer: {selected_layer}
              </Box>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
