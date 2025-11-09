import { useBackend } from '../backend';
import { Box, Button, ColorBox, Input, LabeledList, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';
import { Window } from '../layouts';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    ink_color,
    expanded_parts = [],
    artist_names = {},
    tattoo_designs = {},
    selected_layers = {},
    selected_fonts = {},
    body_parts = [],
  } = data;

  return (
    <Window
      title="Professional Tattoo Kit - DEBUG MODE"
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
                  onClick={() => {
                    act('debug_log', { message: "UI: change_color button clicked" });
                    act('change_color');
                  }}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="fill-drip"
                  tooltip="Refill Ink"
                  onClick={() => {
                    act('debug_log', { message: "UI: refill_ink button clicked" });
                    act('refill_ink');
                  }}
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

        {/* MASSIVE DEBUG INFORMATION SECTION */}
        <Section title="🔍 MASSIVE DEBUG DATA - PLEASE SHOW ALL THIS TEXT" color="purple">
          <Box bold color="white" backgroundColor="black" p={1} mb={1}>
            COPY EVERYTHING IN THIS SECTION AND SEND IT TO THE DEVELOPER
          </Box>

          <Section title="📊 RAW DATA FROM BACKEND" color="average">
            <LabeledList>
              <LabeledList.Item label="target_name">
                <Box color="white" backgroundColor="blue" p={1}>{target_name || "NULL"}</Box>
              </LabeledList.Item>
              <LabeledList.Item label="ink_uses">
                <Box color="white" backgroundColor="blue" p={1}>{ink_uses || "NULL"}</Box>
              </LabeledList.Item>
              <LabeledList.Item label="max_ink_uses">
                <Box color="white" backgroundColor="blue" p={1}>{max_ink_uses || "NULL"}</Box>
              </LabeledList.Item>
              <LabeledList.Item label="ink_color">
                <Box color="white" backgroundColor="blue" p={1}>{ink_color || "NULL"}</Box>
              </LabeledList.Item>
              <LabeledList.Item label="expanded_parts">
                <Box color="white" backgroundColor="blue" p={1}>
                  {expanded_parts && expanded_parts.length > 0 ? expanded_parts.join(", ") : "EMPTY ARRAY"}
                </Box>
              </LabeledList.Item>
            </LabeledList>
          </Section>

          <Section title="🎨 ARTIST NAMES DATA" color="average">
            <Box color="white" backgroundColor="green" p={1}>
              {artist_names && Object.keys(artist_names).length > 0 ? (
                <div>
                  <Box bold>Keys in artist_names: {Object.keys(artist_names).join(", ")}</Box>
                  {Object.entries(artist_names).map(([zone, name]) => (
                    <Box key={zone} mt={1}>
                      <strong>{zone}:</strong>
                      <Box color={name ? "white" : "red"} ml={1}>
                        "{name || "EMPTY STRING"}"
                        {name ? ` (length: ${String(name).length})` : " (NULL)"}
                      </Box>
                    </Box>
                  ))}
                </div>
              ) : (
                <Box color="red" bold>artist_names object is EMPTY or UNDEFINED</Box>
              )}
            </Box>
          </Section>

          <Section title="✏️ TATTOO DESIGNS DATA" color="average">
            <Box color="white" backgroundColor="green" p={1}>
              {tattoo_designs && Object.keys(tattoo_designs).length > 0 ? (
                <div>
                  <Box bold>Keys in tattoo_designs: {Object.keys(tattoo_designs).join(", ")}</Box>
                  {Object.entries(tattoo_designs).map(([zone, design]) => (
                    <Box key={zone} mt={1}>
                      <strong>{zone}:</strong>
                      <Box color={design ? "white" : "red"} ml={1}>
                        "{design || "EMPTY STRING"}"
                        {design ? ` (length: ${String(design).length})` : " (NULL)"}
                      </Box>
                    </Box>
                  ))}
                </div>
              ) : (
                <Box color="red" bold>tattoo_designs object is EMPTY or UNDEFINED</Box>
              )}
            </Box>
          </Section>

          <Section title="📁 BODY PARTS DATA" color="average">
            <Box color="white" backgroundColor="brown" p={1}>
              {body_parts && body_parts.length > 0 ? (
                <div>
                  <Box bold>Number of body parts: {body_parts.length}</Box>
                  {body_parts.map((part, index) => (
                    <Box key={index} mt={1} p={1} backgroundColor="darkred">
                      <Box bold>Part #{index}: {part.name} (zone: {part.zone})</Box>
                      <Box>Covered: {part.covered ? "YES" : "NO"}</Box>
                      <Box>Tattoos: {part.current_tattoos}/{part.max_tattoos}</Box>
                      <Box>Expanded: {expanded_parts.includes(part.zone) ? "YES" : "NO"}</Box>
                      <Box>Preview: {part.preview_text || "NO PREVIEW"}</Box>
                    </Box>
                  ))}
                </div>
              ) : (
                <Box color="red" bold>body_parts array is EMPTY or UNDEFINED</Box>
              )}
            </Box>
          </Section>

          <Section title="🔧 TECHNICAL DATA" color="average">
            <LabeledList>
              <LabeledList.Item label="selected_layers">
                <Box color="white" backgroundColor="purple" p={1}>
                  {selected_layers && Object.keys(selected_layers).length > 0
                    ? JSON.stringify(selected_layers)
                    : "EMPTY OBJECT"}
                </Box>
              </LabeledList.Item>
              <LabeledList.Item label="selected_fonts">
                <Box color="white" backgroundColor="purple" p={1}>
                  {selected_fonts && Object.keys(selected_fonts).length > 0
                    ? JSON.stringify(selected_fonts)
                    : "EMPTY OBJECT"}
                </Box>
              </LabeledList.Item>
              <LabeledList.Item label="Data Types">
                <Box color="white" backgroundColor="purple" p={1}>
                  artist_names type: {typeof artist_names}<br />
                  tattoo_designs type: {typeof tattoo_designs}<br />
                  body_parts type: {Array.isArray(body_parts) ? "Array" : typeof body_parts}<br />
                  artist_names size: {artist_names ? Object.keys(artist_names).length : "NULL"}<br />
                  tattoo_designs size: {tattoo_designs ? Object.keys(tattoo_designs).length : "NULL"}
                </Box>
              </LabeledList.Item>
            </LabeledList>
          </Section>
        </Section>

        <Section title="Body Parts">
          {!body_parts || body_parts.length === 0 ? (
            <Box color="bad">No accessible body parts found!</Box>
          ) : (
            body_parts.map((part) => (
              <BodyPartSection
                key={part.zone}
                part={part}
                expanded={expanded_parts.includes(part.zone)}
                artist_name={artist_names[part.zone]}
                tattoo_design={tattoo_designs[part.zone]}
                selected_layer={selected_layers[part.zone]}
                selected_font={selected_fonts[part.zone]}
                ink_uses={ink_uses}
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
  const {
    part,
    expanded,
    artist_name,
    tattoo_design,
    selected_layer = 2,
    selected_font = "Pen",
    ink_uses = 0,
    act,
  } = props;

  const part_name = part?.name || "Unknown";
  const part_zone = part?.zone || "unknown";
  const part_covered = part?.covered || false;
  const part_current_tattoos = part?.current_tattoos || 0;
  const part_max_tattoos = part?.max_tattoos || 5;
  const part_preview_text = part?.preview_text || "No tattoos yet.";

  const fontOptions = [
    { key: "Pen", label: "Pen" },
    { key: "Fountain Pen", label: "Fountain Pen" },
    { key: "Crayon", label: "Crayon" },
    { key: "Printer", label: "Printer" },
    { key: "Charcoal", label: "Charcoal" },
  ];

  // Safe value handler to prevent undefined errors
  const getSafeValue = (value) => {
    if (value === undefined || value === null) {
      return '';
    }
    return value;
  };

  // Safe length handler
  const getSafeLength = (value) => {
    if (value === undefined || value === null) {
      return 0;
    }
    return String(value).length;
  };

  return (
    <Section
      title={
        <Box inline>
          {part_name}
          {part_covered && (
            <Box inline color="bad" ml={1}>
              (Covered)
            </Box>
          )}
          <Box inline color="label" ml={1}>
            ({part_current_tattoos}/{part_max_tattoos} tattoos)
          </Box>
        </Box>
      }
      buttons={
        <Button
          icon={expanded ? 'chevron-up' : 'chevron-down'}
          color="transparent"
          onClick={() => {
            act('debug_log', { message: `UI: toggle_expand for zone ${part_zone}, currently ${expanded ? 'expanded' : 'collapsed'}` });
            act('toggle_expand', { zone: part_zone });
          }}
        />
      }>
      {!expanded ? (
        <Box color="label">
          <div dangerouslySetInnerHTML={{ __html: part_preview_text }} />
        </Box>
      ) : (
        <Stack vertical>
          <Stack.Item>
            <Box color="label" mb={1}>
              <div dangerouslySetInnerHTML={{ __html: part_preview_text }} />
            </Box>
          </Stack.Item>

          {/* DEBUG: Current Input Values */}
          <Stack.Item>
            <Section title={`🔍 DEBUG: ${part_zone.toUpperCase()} INPUT VALUES`} color="blue">
              <LabeledList>
                <LabeledList.Item label="Artist Name Value">
                  <Box color={artist_name ? "good" : "bad"} backgroundColor="black" p={1}>
                    {artist_name ? `"${artist_name}"` : "NULL OR EMPTY"}
                    {artist_name && ` (length: ${getSafeLength(artist_name)})`}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Tattoo Design Value">
                  <Box color={tattoo_design ? "good" : "bad"} backgroundColor="black" p={1}>
                    {tattoo_design ? `"${tattoo_design}"` : "NULL OR EMPTY"}
                    {tattoo_design && ` (length: ${getSafeLength(tattoo_design)})`}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Selected Layer">
                  <Box backgroundColor="black" p={1}>{selected_layer}</Box>
                </LabeledList.Item>
                <LabeledList.Item label="Selected Font">
                  <Box backgroundColor="black" p={1}>{selected_font}</Box>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          <Stack.Item>
            <LabeledList>
              <LabeledList.Item label="Artist Name">
                <Input
                  fluid
                  value={getSafeValue(artist_name)}
                  placeholder="Enter artist name..."
                  onChange={(e, value) => {
                    const safeValue = getSafeValue(value);
                    act('debug_log', {
                      message: `UI: set_artist for ${part_zone} with value: "${safeValue}" (length: ${getSafeLength(safeValue)})`
                    });
                    act('set_artist', {
                      zone: part_zone,
                      value: safeValue,
                    });
                  }}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Tattoo Design">
                <Input
                  fluid
                  value={getSafeValue(tattoo_design)}
                  placeholder="Describe the tattoo design..."
                  onChange={(e, value) => {
                    const safeValue = getSafeValue(value);
                    act('debug_log', {
                      message: `UI: set_design for ${part_zone} with value: "${safeValue}" (length: ${getSafeLength(safeValue)})`
                    });
                    act('set_design', {
                      zone: part_zone,
                      value: safeValue,
                    });
                  }}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Layer">
                <Stack>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 1}
                      onClick={() => {
                        act('debug_log', { message: `UI: set_layer for ${part_zone} to 1` });
                        act('set_layer', { zone: part_zone, layer: 1 });
                      }}>
                      Under
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 2}
                      onClick={() => {
                        act('debug_log', { message: `UI: set_layer for ${part_zone} to 2` });
                        act('set_layer', { zone: part_zone, layer: 2 });
                      }}>
                      Normal
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 3}
                      onClick={() => {
                        act('debug_log', { message: `UI: set_layer for ${part_zone} to 3` });
                        act('set_layer', { zone: part_zone, layer: 3 });
                      }}>
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
                      onClick={() => {
                        act('debug_log', { message: `UI: set_font for ${part_zone} to ${font.key}` });
                        act('set_font', { zone: part_zone, font: font.key });
                      }}>
                      {font.label}
                    </Tabs.Tab>
                  ))}
                </Tabs>
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>

          <Stack.Item mt={1}>
            <Section title={`🚨 APPLY TATTOO DEBUG - ${part_zone.toUpperCase()}`} color="red">
              <LabeledList>
                <LabeledList.Item label="Can Apply?">
                  <Box color={
                    !part_covered &&
                    part_current_tattoos < part_max_tattoos &&
                    ink_uses > 0 &&
                    artist_name &&
                    tattoo_design ? "good" : "bad"
                  } backgroundColor="black" p={1}>
                    {!part_covered ? "✓ Not Covered" : "✗ Covered"} |
                    {part_current_tattoos < part_max_tattoos ? "✓ Has Space" : "✗ No Space"} |
                    {ink_uses > 0 ? "✓ Has Ink" : "✗ No Ink"} |
                    {artist_name ? "✓ Has Artist" : "✗ No Artist"} |
                    {tattoo_design ? "✓ Has Design" : "✗ No Design"}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Values Being Sent">
                  <Box backgroundColor="black" p={1}>
                    {`Artist: "${getSafeValue(artist_name) || "EMPTY"}" | Design: "${getSafeValue(tattoo_design) || "EMPTY"}"`}
                  </Box>
                </LabeledList.Item>
              </LabeledList>
            </Section>

            <Button
              fluid
              icon="paint-brush"
              color="good"
              disabled={part_covered || part_current_tattoos >= part_max_tattoos || ink_uses <= 0 || !artist_name || !tattoo_design}
              onClick={() => {
                act('debug_log', {
                  message: `UI: APPLY_TATTOO for ${part_zone} - Artist: "${getSafeValue(artist_name)}", Design: "${getSafeValue(tattoo_design)}"`
                });
                act('apply_tattoo', {
                  zone: part_zone,
                  artist: getSafeValue(artist_name),
                  design: getSafeValue(tattoo_design)
                });
              }}>
              Apply Tattoo to {part_name}
            </Button>
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
};
