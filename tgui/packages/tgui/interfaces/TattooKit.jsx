import { useBackend } from '../backend';
import {
  Box,
  Button,
  ColorBox,
  Input,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Tabs
} from 'tgui-core/components';
import { Window } from '../layouts';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    ink_color,
    body_parts = [],
  } = data;

  return (
    <Window
      title="Professional Tattoo Kit"
      width={900}
      height={700}>
      <Window.Content scrollable>
        <Section
          title={`Target: ${target_name || "No Target"}`}
          buttons={
            <Stack>
              <Stack.Item>
                <ColorBox color={ink_color || "#000000"} />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="palette"
                  tooltip="Change Ink Color"
                  onClick={() => act('change_color')}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="fill-drip"
                  tooltip="Refill Ink"
                  onClick={() => act('refill_ink')}
                />
              </Stack.Item>
            </Stack>
          }>
          <LabeledList>
            <LabeledList.Item label="Ink Remaining">
              <ProgressBar
                value={ink_uses || 0}
                minValue={0}
                maxValue={max_ink_uses || 30}
                color={(ink_uses || 0) > 0 ? 'good' : 'bad'}>
                {ink_uses || 0}/{max_ink_uses || 30}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Body Parts">
          {!body_parts || body_parts.length === 0 ? (
            <Box color="bad">No accessible body parts found!</Box>
          ) : (
            body_parts.map((part) => (
              <BodyPartSection
                key={part.zone}
                part={part}
                act={act}
              />
            ))
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};

const BodyPartSection = (props) => {
  const { part, act } = props;

  const {
    zone,
    name,
    covered,
    current_tattoos,
    max_tattoos,
    preview_text,
    expanded,
    artist_name,
    tattoo_design,
    selected_layer,
    selected_font,
    can_apply,
  } = part;

  const fontOptions = [
    { key: "Pen", label: "Pen" },
    { key: "Fountain Pen", label: "Fountain Pen" },
    { key: "Crayon", label: "Crayon" },
    { key: "Printer", label: "Printer" },
    { key: "Charcoal", label: "Charcoal" },
  ];

  return (
    <Section
      title={
        <Box inline>
          {name}
          {covered && (
            <Box inline color="bad" ml={1}>
              (Covered)
            </Box>
          )}
          <Box inline color="label" ml={1}>
            ({current_tattoos}/{max_tattoos} tattoos)
          </Box>
        </Box>
      }
      buttons={
        <Button
          icon={expanded ? 'chevron-up' : 'chevron-down'}
          color="transparent"
          onClick={() => act('toggle_expand', { zone: zone })}
        />
      }>
      {!expanded ? (
        <Box color="label">
          <div dangerouslySetInnerHTML={{ __html: preview_text }} />
        </Box>
      ) : (
        <Stack vertical>
          <Stack.Item>
            <Box color="label" mb={1}>
              <div dangerouslySetInnerHTML={{ __html: preview_text }} />
            </Box>
          </Stack.Item>

          <Stack.Item>
            <LabeledList>
              <LabeledList.Item label="Artist Name">
                <Input
                  fluid
                  value={artist_name || ''}
                  placeholder="Enter artist name..."
                  onChange={(e, value) => act('set_artist', {
                    zone: zone,
                    value: value,
                  })}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Tattoo Design">
                <Input
                  fluid
                  value={tattoo_design || ''}
                  placeholder="Describe the tattoo design... Use %s for signature, :heart: for emoji"
                  onChange={(e, value) => act('set_design', {
                    zone: zone,
                    value: value,
                  })}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Layer">
                <Stack>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 1}
                      onClick={() => act('set_layer', {
                        zone: zone,
                        layer: 1
                      })}>
                      Under
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 2}
                      onClick={() => act('set_layer', {
                        zone: zone,
                        layer: 2
                      })}>
                      Normal
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 3}
                      onClick={() => act('set_layer', {
                        zone: zone,
                        layer: 3
                      })}>
                      Over
                    </Button>
                  </Stack.Item>
                </Stack>
              </LabeledList.Item>

              <LabeledList.Item label="Font">
                <Tabs>
                  {fontOptions.map((font) => (
                    <Tabs.Tab
                      key={font.key}
                      selected={selected_font === font.key}
                      onClick={() => act('set_font', {
                        zone: zone,
                        font: font.key
                      })}>
                      {font.label}
                    </Tabs.Tab>
                  ))}
                </Tabs>
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>

          <Stack.Item mt={1}>
            <Button
              fluid
              icon="paint-brush"
              color="good"
              disabled={!can_apply}
              onClick={() => act('apply_tattoo', { zone: zone })}>
              Apply Tattoo to {name}
            </Button>
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
};
