/*
Copyright (c) 2021, MapTiler.com & OpenMapTiles contributors.
All rights reserved.

Code license: BSD 3-Clause License

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Design license: CC-BY 4.0

See https://github.com/openmaptiles/openmaptiles/blob/master/LICENSE.md for details on usage
*/
package org.openmaptiles.layers;

import static java.util.Map.entry;
import static org.openmaptiles.util.Utils.coalesce;
import static org.openmaptiles.util.Utils.nullIfEmpty;
import static org.openmaptiles.util.Utils.nullIfLong;
import static org.openmaptiles.util.Utils.nullOrEmpty;

import com.carrotsearch.hppc.LongIntMap;
import com.onthegomap.planetiler.FeatureCollector;
import com.onthegomap.planetiler.ForwardingProfile;
import com.onthegomap.planetiler.VectorTile;
import com.onthegomap.planetiler.collection.Hppc;
import com.onthegomap.planetiler.config.PlanetilerConfig;
import com.onthegomap.planetiler.expression.MultiExpression;
import com.onthegomap.planetiler.stats.Stats;
import com.onthegomap.planetiler.util.Parse;
import com.onthegomap.planetiler.util.Translations;
import java.util.List;
import java.util.Map;
import org.openmaptiles.generated.OpenMapTilesSchema;
import org.openmaptiles.generated.Tables;
import org.openmaptiles.util.OmtLanguageUtils;

/**
 * Defines the logic for generating map elements for things like shops, parks, and schools in the {@code poi} layer from
 * source features.
 * <p>
 * This class is ported to Java from
 * <a href="https://github.com/openmaptiles/openmaptiles/tree/master/layers/poi">OpenMapTiles poi sql files</a>.
 */
public class Poi implements
  OpenMapTilesSchema.Poi,
  Tables.OsmPoiPoint.Handler,
  Tables.OsmPoiPolygon.Handler,
  ForwardingProfile.FeaturePostProcessor {

  /*
   * process() creates the raw POI feature from OSM elements and postProcess()
   * assigns the feature rank from order in the tile at render-time.
   */

  private static final Map<String, Integer> CLASS_RANKS = Map.ofEntries(
    entry(FieldValues.CLASS_HOSPITAL, 20),
    entry(FieldValues.CLASS_RAILWAY, 40),
    entry(FieldValues.CLASS_BUS, 50),
    entry(FieldValues.CLASS_ATTRACTION, 70),
    entry(FieldValues.CLASS_HARBOR, 75),
    entry(FieldValues.CLASS_COLLEGE, 80),
    entry(FieldValues.CLASS_SCHOOL, 85),
    entry(FieldValues.CLASS_STADIUM, 90),
    entry("zoo", 95),
    entry(FieldValues.CLASS_TOWN_HALL, 100),
    entry(FieldValues.CLASS_CAMPSITE, 110),
    entry(FieldValues.CLASS_CEMETERY, 115),
    entry(FieldValues.CLASS_PARK, 120),
    entry(FieldValues.CLASS_LIBRARY, 130),
    entry("police", 135),
    entry(FieldValues.CLASS_POST, 140),
    entry(FieldValues.CLASS_GOLF, 150),
    entry(FieldValues.CLASS_SHOP, 400),
    entry(FieldValues.CLASS_GROCERY, 500),
    entry(FieldValues.CLASS_FAST_FOOD, 600),
    entry(FieldValues.CLASS_CLOTHING_STORE, 700),
    entry(FieldValues.CLASS_BAR, 800)
  );
  private final MultiExpression.Index<String> classMapping;
  private final Translations translations;

  public Poi(Translations translations, PlanetilerConfig config, Stats stats) {
    this.classMapping = FieldMappings.Class.index();
    this.translations = translations;
  }

  static int poiClassRank(String clazz) {
    return CLASS_RANKS.getOrDefault(clazz, 1_000);
  }

  private String poiClass(String subclass, String mappingKey) {
    subclass = coalesce(subclass, "");
    return classMapping.getOrElse(Map.of(
      "subclass", subclass,
      "mapping_key", coalesce(mappingKey, "")
    ), subclass);
  }

  private int minzoom(String subclass, String mappingKey) {
    boolean lowZoom = ("station".equals(subclass) && "railway".equals(mappingKey)) ||
      "halt".equals(subclass) || "ferry_terminal".equals(subclass);
    return lowZoom ? 12 : 14;
  }

  @Override
  public void process(Tables.OsmPoiPoint element, FeatureCollector features) {
    // TODO handle uic_ref => agg_stop
    setupPoiFeature(element, features.point(LAYER_NAME));
  }

  @Override
  public void process(Tables.OsmPoiPolygon element, FeatureCollector features) {
    setupPoiFeature(element, features.centroidIfConvex(LAYER_NAME));
  }

  private <T extends Tables.WithSubclass & Tables.WithStation & Tables.WithFunicular & Tables.WithSport & Tables.WithInformation & Tables.WithReligion & Tables.WithMappingKey & Tables.WithName & Tables.WithIndoor & Tables.WithLayer & Tables.WithSource & Tables.WithOperator & Tables.WithNetwork> void setupPoiFeature(
    T element, FeatureCollector.Feature output) {
    String rawSubclass = element.subclass();
    if ("station".equals(rawSubclass) && "subway".equals(element.station())) {
      rawSubclass = "subway";
    }
    if ("station".equals(rawSubclass) && "yes".equals(element.funicular())) {
      rawSubclass = "halt";
    }

    // ATM names fall back to operator, or else network
    String name = element.name();
    var tags = element.source().tags();
    if ("atm".equals(rawSubclass) && nullOrEmpty(name)) {
      name = coalesce(nullIfEmpty(element.operator()), nullIfEmpty(element.network()));
      if (name != null) {
        tags.put("name", name);
      }
    }

    String subclass = switch (rawSubclass) {
      case "information" -> nullIfEmpty(element.information());
      case "place_of_worship" -> nullIfEmpty(element.religion());
      case "pitch" -> nullIfEmpty(element.sport());
      default -> rawSubclass;
    };
    String poiClass = poiClass(rawSubclass, element.mappingKey());
    int poiClassRank = poiClassRank(poiClass);
    int rankOrder = poiClassRank + ((nullOrEmpty(name)) ? 2000 : 0);

    output.setBufferPixels(BUFFER_SIZE)
      .setAttr(Fields.CLASS, poiClass)
      .setAttr(Fields.SUBCLASS, subclass)
      .setAttr(Fields.LAYER, nullIfLong(element.layer(), 0))
      .setAttr(Fields.LEVEL, Parse.parseLongOrNull(element.source().getTag("level")))
      .setAttr(Fields.INDOOR, element.indoor() ? 1 : null)
      .setAttr("access", element.source().getTag("access"))
      .putAttrs(OmtLanguageUtils.getNames(element.source().tags(), translations))
      .setPointLabelGridPixelSize(14, 64)
      .setSortKey(rankOrder)
      .setMinZoom(minzoom(element.subclass(), element.mappingKey()));
    putDetails(element.source(), output);
  }

  /** The tags the myTracks app shows on a place's card, offline (change {@code add-poi-attributes}). */
  private static final List<String> DETAIL_TAGS = List.of(
    "opening_hours", "phone", "website", "wheelchair", "cuisine", "operator", "seasonal",
    "drinking_water", "shelter_type", "fee"
  );
  /** Counts among them, as numbers. */
  private static final List<String> DETAIL_NUMBERS = List.of("beds", "capacity");
  /** Where a tag is often kept under another key instead. */
  private static final Map<String, String> DETAIL_ALTERNATIVES = Map.of(
    "phone", "contact:phone",
    "website", "contact:website"
  );
  /** Values longer than this are cut, so that a long text cannot grow a tile. */
  private static final int DETAIL_MAX_LENGTH = 255;
  /** Only the zoom the app's place index reads and the map shows at street level. */
  private static final int DETAIL_ZOOM = 14;

  /** The place details at zoom 14 only; a feature without a tag carries nothing for it. */
  private static void putDetails(com.onthegomap.planetiler.reader.SourceFeature source, FeatureCollector.Feature output) {
    for (String key : DETAIL_TAGS) {
      String value = detail(source.getTag(key));
      if (value == null && DETAIL_ALTERNATIVES.containsKey(key)) {
        value = detail(source.getTag(DETAIL_ALTERNATIVES.get(key)));
      }
      if (value != null) {
        output.setAttrWithMinzoom(key, value, DETAIL_ZOOM);
      }
    }
    for (String key : DETAIL_NUMBERS) {
      Long number = Parse.parseLongOrNull(source.getTag(key));
      if (number != null && number > 0) {
        output.setAttrWithMinzoom(key, number, DETAIL_ZOOM);
      }
    }
  }

  private static String detail(Object value) {
    if (value == null) {
      return null;
    }
    String text = value.toString().strip();
    if (text.isEmpty()) {
      return null;
    }
    return text.length() > DETAIL_MAX_LENGTH ? text.substring(0, DETAIL_MAX_LENGTH) : text;
  }

  @Override
  public List<VectorTile.Feature> postProcess(int zoom, List<VectorTile.Feature> items) {
    // infer the "rank" field from the order of features within each label grid square
    LongIntMap groupCounts = Hppc.newLongIntHashMap();
    for (VectorTile.Feature feature : items) {
      int gridrank = groupCounts.getOrDefault(feature.group(), 1);
      groupCounts.put(feature.group(), gridrank + 1);
      if (!feature.attrs().containsKey(Fields.RANK)) {
        feature.attrs().put(Fields.RANK, gridrank);
      }
    }
    return items;
  }
}
