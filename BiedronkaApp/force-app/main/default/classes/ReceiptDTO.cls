/**
 * Data Transfer Object for deserializing Receipt JSON.
 * Includes the envelope (Base64/JWT) and decoded payload structure.
 */
public class ReceiptDTO {
    // Envelope fields
    public String protoVersion;
    public String data;

    // Decoded payload structure (raw JSON)
    public DokumentWrapper dokument;

    public class DokumentWrapper {
        public NaglowekWrapper naglowek;
        public PodmiotWrapper podmiot1;
        public ParagonWrapper paragon;
    }

    public class NaglowekWrapper {
        public String dataJPK;
    }

    public class PodmiotWrapper {
        public String NIP;
        public String nazwaPod;
        public AdresPodWrapper adresPod;
    }

    public class AdresPodWrapper {
        public String miejsc;
        public String ulica;
    }

    public class ParagonWrapper {
        public String nrUnik;
        public Integer nrDok;
        public List<PozycjaWrapper> pozycja;
        public List<PlatnoscWrapper> platnosc;
        public PodsumWrapper podsum;
        public TotalWrapper total;
    }

    public class PlatnoscWrapper {
        public String nazwa;
    }

    public class PodsumWrapper {
        public Integer sumaOpust;
    }

    public class TotalWrapper {
        public Integer zaplZwrot;
    }

    public class PozycjaWrapper {
        public TowarWrapper towar;
        public DiscountDetail discountLine;
    }

    public class DiscountDetail {
        public Integer wart;
        public Boolean isDiscount;
    }

    public class TowarWrapper {
        public String nazwa;
        public Integer cena;
        public String ilosc;
        public Integer brutto;
        public DiscountInfo rabat;

        public Decimal getDecimalPrice() {
            if (this.cena != null) {
                return Decimal.valueOf(this.cena).divide(100, 2);
            }
            return null;
        }
    }

    public class DiscountInfo {
        public Integer wart;
        public String opis;
    }

    public static Datetime parseDataJPK(String dataJPK) {
        if (String.isNotBlank(dataJPK)) {
            return (Datetime) JSON.deserialize('"' + dataJPK + '"', Datetime.class);
        }
        return Datetime.now();
    }
}
