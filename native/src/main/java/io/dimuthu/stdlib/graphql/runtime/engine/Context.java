package io.dimuthu.stdlib.graphql.runtime.engine;

import io.ballerina.runtime.api.PredefinedTypes;
import io.ballerina.runtime.api.creators.TypeCreator;
import io.ballerina.runtime.api.creators.ValueCreator;
import io.ballerina.runtime.api.types.ArrayType;
import io.ballerina.runtime.api.types.Type;
import io.ballerina.runtime.api.values.BArray;
import io.ballerina.runtime.api.values.BMap;
import io.ballerina.runtime.api.values.BObject;
import io.ballerina.runtime.api.values.BString;
import io.ballerina.runtime.api.values.BValue;

import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import static io.dimuthu.stdlib.graphql.runtime.utils.ModuleUtils.getModule;

/**
 * This class provides native implementations of the Ballerina Context class.
 */
public class Context {
    private final ConcurrentHashMap<BString, Object> attributes;
    private final ConcurrentHashMap<Integer, BMap<BString, BObject>> errors;
    // Provides mapping between user defined id and DataLoader
    private final ConcurrentHashMap<BString, BObject> idDataLoaderMap;
    private final ConcurrentHashMap<BString, BObject> uuidPlaceholderMap;
    private final ConcurrentHashMap<BString, BObject> unResolvedPlaceholders;
    private final AtomicBoolean containPlaceholders;
    // Tracks the number of Placeholders needs to be resolved
    private final AtomicInteger unResolvedPlaceholderCount;
    private final AtomicInteger unResolvedPlaceholderNodeCount;
    private final AtomicInteger keyCounter;
    private static final Object NullObject = new Object();

    private static final String CONTEXT = "context";
    private static final String ERROR_DETAIL = "ErrorDetail";

    private Context() {
        attributes = new ConcurrentHashMap<>();
        errors = new ConcurrentHashMap<>();
        idDataLoaderMap = new ConcurrentHashMap<>();
        uuidPlaceholderMap = new ConcurrentHashMap<>();
        unResolvedPlaceholders = new ConcurrentHashMap<>();
        containPlaceholders = new AtomicBoolean(false);
        unResolvedPlaceholderCount = new AtomicInteger(0);
        keyCounter = new AtomicInteger(0);
        unResolvedPlaceholderNodeCount = new AtomicInteger(0);
    }

    public static void intializeContext(BObject context) {
        context.addNativeData(CONTEXT, new Context());
    }

    public static void registerDataLoader(BObject object, BString key, BObject dataloader) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.registerDataLoader(key, dataloader);
    }

    public static void setAttribute(BObject object, BString key, Object value) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.setAttribute(key, value);
    }

    public static Object getAttribute(BObject object, BString key) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getAttribute(key);
    }

    public static void addError(BObject object, BMap<BString, BObject> error) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.addError(error);
    }

    public static void addErrors(BObject object, BArray errors) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.addErrors(errors);
    }

    public static BArray getErrors(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getErrors();
    }

    public static void resetErrors(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.resetErrors();
    }

    public static Object removeAttribute(BObject object, BString key) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.removeAttribute(key);
    }

    public static BObject getDataLoader(BObject object, BString key) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getDataLoader(key);
    }

    public static BArray getDataloaderIds(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getDataloaderIds();
    }

    public static BArray getUnresolvedPlaceholders(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getUnresolvedPlaceholders();
    }

    public static void removeAllUnresolvedPlaceholders(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.removeAllUnresolvedPlaceholders();
    }

    public static BObject getPlaceholder(BObject object, BString uuid) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getPlaceholder(uuid);
    }

    public static int getUnresolvedPlaceholderCount(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getUnresolvedPlaceholderCount();
    }

    public static int getUnresolvedPlaceholderNodeCount(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.getUnresolvedPlaceholderNodeCount();
    }

    public static void decrementUnresolvedPlaceholderNodeCount(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.decrementUnresolvedPlaceholderNodeCount();
    }

    public static void decrementUnresolvedPlaceholderCount(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.decrementUnresolvedPlaceholderCount();
    }

    public static void addUnresolvedPlaceholder(BObject object, BString uuid, BObject placeholder) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.addUnresolvedPlaceholder(uuid, placeholder);
    }

    public static boolean hasPlaceholders(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        return context.hasPlaceholders();
    }

    public static void clearPlaceholders(BObject object) {
        Context context = (Context) object.getNativeData(CONTEXT);
        context.clearPlaceholders();
    }

    private void setAttribute(BString key, Object value) {
        if (value == null) {
            attributes.put(key, NullObject);
        } else {
            attributes.put(key, value);
        }
    }

    private Object getAttribute(BString key) {
        Object value = attributes.get(key);
        if (value != null && value.equals(NullObject)) {
            return null;
        }
        return value;
    }

    private Object removeAttribute(BString key) {
        Object value = attributes.remove(key);
        if (value != null && value.equals(NullObject)) {
            return null;
        }
        return value;
    }

    private BArray getErrors() {
        Object[] valueArray = errors.values().toArray();
        Type type = ValueCreator.createRecordValue(getModule(), ERROR_DETAIL).getType();
        ArrayType arrayType = TypeCreator.createArrayType(type);
        BArray values = ValueCreator.createArrayValue(valueArray, arrayType);
        return values;
    }

    private void addError(BMap<BString, BObject> error) {
        errors.put(keyCounter.getAndIncrement(), error);
    }

    @SuppressWarnings("unchecked")
    private void addErrors(BArray errors) {
        for (int i = 0; i < errors.size(); i++) {
            BMap<BString, BObject> error = (BMap<BString, BObject>) errors.get(i);
            this.errors.put(keyCounter.getAndIncrement(), error);
        }
    }

    private void resetErrors() {
        errors.clear();
    }

    private void registerDataLoader(BString key, BObject dataloader) {
        idDataLoaderMap.put(key, dataloader);
    }

    private BObject getDataLoader(BString key) {
        return idDataLoaderMap.get(key);
    }

    private BArray getDataloaderIds() {
        BArray values = ValueCreator.createArrayValue(TypeCreator.createArrayType(PredefinedTypes.TYPE_STRING));
        idDataLoaderMap.forEach((key, value) -> {
            values.append(key);
        });
        return values;
    }

    private BArray getUnresolvedPlaceholders() {
        Object[] valueArray = unResolvedPlaceholders.values().toArray();
        ArrayType arrayType = TypeCreator.createArrayType(((BValue) valueArray[0]).getType());
        BArray values = ValueCreator.createArrayValue(valueArray, arrayType);
        return values;
    }

    private void removeAllUnresolvedPlaceholders() {
        unResolvedPlaceholders.clear();
    }

    private BObject getPlaceholder(BString uuid) {
        return uuidPlaceholderMap.remove(uuid);
    }

    private int getUnresolvedPlaceholderCount() {
        return unResolvedPlaceholderCount.get();
    }

    private int getUnresolvedPlaceholderNodeCount() {
        return unResolvedPlaceholderNodeCount.get();
    }

    private void decrementUnresolvedPlaceholderNodeCount() {
        unResolvedPlaceholderNodeCount.decrementAndGet();
    }

    private void decrementUnresolvedPlaceholderCount() {
        unResolvedPlaceholderCount.decrementAndGet();
    }

    private void addUnresolvedPlaceholder(BString uuid, BObject placeholder) {
        containPlaceholders.set(true);
        uuidPlaceholderMap.put(uuid, placeholder);
        unResolvedPlaceholders.put(uuid, placeholder);
        unResolvedPlaceholderCount.incrementAndGet();
        unResolvedPlaceholderNodeCount.incrementAndGet();
    }

    private boolean hasPlaceholders() {
        return containPlaceholders.get();
    }

    private void clearPlaceholders() {
        unResolvedPlaceholders.clear();
        uuidPlaceholderMap.clear();
        containPlaceholders.set(false);
    }
}
