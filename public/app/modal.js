export default {
  props: {
    title: String,
    noClose: Boolean,
    extraClasses: String,
  },
  template: `
  <div 
    :class="extraClasses" 
    class="
    shadow-xl
    shadow-slate-600
    z-[1000] 
    bg-[#212126] 
    border 
    rounded 
    min-w-96 
    h-full
    lg:w-[1200px]
    max-lg:w-11/12
    min-h-[300px] 
    max-h-[800px] 
    overflow-y-auto 
    p-2 
    fixed 
    inset-x-1/2 
    -translate-x-1/2 
    inset-y-1/2 
    -translate-y-1/2
  ">
    <div class="flex flex-row justify-between items-center">
      <button v-if="!noClose" @click="$emit('close')" class="bg-none border-none">
        x
      </button>
      <div v-else></div>
      <h1 class="h1 font-bold">{{ title }}</h1>
      <div></div>
    </div>
    <div class="mt-2 w-full h-full">
      <slot/>
    </div>
  </div>
  `
}
